module Capturers
  # Picks the capture methods for a URL. The rules, in order:
  #
  #   1. github.com/<owner>/<repo>                   github, git, page
  #   2. a repo on another git host, or a .git URL    git, page
  #   3. Google Docs, Slides, Sheets or Drawings      document, page
  #   4. a video host that yt-dlp knows               video, page
  #   5. a post URL on a gallery host                 gallery, page
  #   6. a file: by extension, or by the Content-Type  document (office or PDF) or file
  #      of a HEAD request (ArchiveJob passes it in)
  #   7. everything else                              page
  #
  # The router never pulls a whole account: a profile URL on a gallery host is a page, and a
  # GitHub owner URL is a page. The table here is the contract; change the design doc too.
  module Router
    KINDS = %w[page repo document video gallery file].freeze
    METHODS = %w[page git github document video gallery file].freeze

    CAPTURERS = {
      "page" => "Capturers::Page",
      "git" => "Capturers::Git",
      "github" => "Capturers::Github",
      "document" => "Capturers::Document",
      "video" => "Capturers::Video",
      "gallery" => "Capturers::Gallery",
      "file" => "Capturers::File"
    }.freeze

    # Owner names on github.com that are not users or organizations.
    GITHUB_RESERVED = %w[
      about apps blog collections contact customer-stories enterprise events explore features
      issues login marketplace new nonprofit notifications orgs organizations pricing pulls
      security settings site sponsors team topics trending users
    ].freeze
    GIT_HOSTS = %w[gitlab.com codeberg.org bitbucket.org git.sr.ht gitea.com].freeze
    GOOGLE_DOC_PATH = %r{\A/(document|presentation|spreadsheets|drawings)/d/([\w-]+)}
    VIDEO_HOSTS = %w[
      youtube.com youtu.be vimeo.com tiktok.com loom.com twitch.tv dailymotion.com streamable.com
      rumble.com odysee.com
    ].freeze
    # Post-shaped paths only, per host. A profile URL does not match.
    GALLERY_POSTS = {
      "instagram.com" => %r{\A/(p|reel|tv)/[\w-]+},
      "x.com" => %r{\A/[^/]+/status/\d+},
      "twitter.com" => %r{\A/[^/]+/status/\d+},
      "reddit.com" => %r{\A/r/[^/]+/comments/\w+},
      "bsky.app" => %r{\A/profile/[^/]+/post/\w+},
      "flickr.com" => %r{\A/photos/[^/]+/\d+},
      "imgur.com" => %r{\A/(a|gallery)/\w+},
      "tumblr.com" => %r{/post/\d+},
      "pinterest.com" => %r{\A/pin/\d+},
      "deviantart.com" => %r{\A/[^/]+/art/[\w-]+},
      "artstation.com" => %r{\A/artwork/\w+}
    }.freeze
    DOCUMENT_EXTENSIONS = %w[pdf pptx ppt docx doc xlsx xls odp odt ods key pages numbers rtf epub].freeze
    DOCUMENT_TYPES = %w[
      application/pdf
      application/vnd.openxmlformats-officedocument.presentationml.presentation
      application/vnd.openxmlformats-officedocument.wordprocessingml.document
      application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
      application/vnd.ms-powerpoint application/msword application/vnd.ms-excel
      application/vnd.oasis.opendocument.presentation application/vnd.oasis.opendocument.text
      application/vnd.oasis.opendocument.spreadsheet application/vnd.apple.keynote
      application/rtf application/epub+zip
    ].freeze
    HTML_TYPES = %w[text/html application/xhtml+xml].freeze

    def self.capturer_for(method_name)
      CAPTURERS.fetch(method_name).constantize
    end

    # The methods for a URL, in run order. `content_type` is what a HEAD request said, or nil.
    def self.methods_for(url, content_type: nil)
      case kind_for(url, content_type: content_type)
      when "repo" then github?(url) ? %w[github git page] : %w[git page]
      when "document" then google_document?(url) ? %w[document page] : %w[document]
      when "video" then %w[video page]
      when "gallery" then %w[gallery page]
      when "file" then %w[file]
      else %w[page]
      end
    end

    # The archive kind for a URL. Without a content type, a URL with no other match is a page.
    def self.kind_for(url, content_type: nil)
      uri = parse(url)
      return "page" unless uri

      return "repo" if github?(url) || git_host?(uri) || uri.path.end_with?(".git")
      return "document" if google_document?(url) || document_extension?(uri)
      return "video" if host_in?(uri, VIDEO_HOSTS)
      return "gallery" if gallery_post?(uri)

      type = content_type.to_s.split(";").first.to_s.strip.downcase
      return "document" if DOCUMENT_TYPES.include?(type)
      return "file" if type.present? && !HTML_TYPES.include?(type) && !type.start_with?("text/")

      "page"
    end

    # github.com/<owner>/<repo>, with or without a deeper path, and not a reserved owner.
    def self.github?(url)
      uri = parse(url)
      return false unless uri && bare_host(uri) == "github.com"

      owner, repo = uri.path.split("/").reject(&:empty?).first(2)
      owner.present? && repo.present? && !GITHUB_RESERVED.include?(owner.downcase)
    end

    # ["owner", "repo"] for a GitHub repo URL, or nil.
    def self.github_repo(url)
      return nil unless github?(url)

      owner, repo = parse(url).path.split("/").reject(&:empty?).first(2)
      [ owner, repo.delete_suffix(".git") ]
    end

    def self.google_document?(url)
      uri = parse(url)
      uri && bare_host(uri) == "docs.google.com" && uri.path.match?(GOOGLE_DOC_PATH)
    end

    # ["presentation", "<id>"] for a Google Docs URL, or nil.
    def self.google_document(url)
      match = parse(url)&.path&.match(GOOGLE_DOC_PATH)
      match && [ match[1], match[2] ]
    end

    def self.git_host?(uri)
      return false unless host_in?(uri, GIT_HOSTS)

      uri.path.split("/").reject(&:empty?).length >= 2
    end

    def self.document_extension?(uri)
      DOCUMENT_EXTENSIONS.include?(::File.extname(uri.path).delete_prefix(".").downcase)
    end

    def self.gallery_post?(uri)
      pattern = GALLERY_POSTS[bare_host(uri)]
      pattern.present? && uri.path.match?(pattern)
    end

    def self.host_in?(uri, hosts)
      hosts.include?(bare_host(uri))
    end

    # The host without a leading "www." or "m.".
    def self.bare_host(uri)
      uri.host.to_s.downcase.sub(/\A(www|m|mobile)\./, "")
    end

    def self.parse(url)
      uri = URI.parse(url.to_s.strip)
      uri.is_a?(URI::HTTP) && uri.host.present? ? uri : nil
    rescue URI::InvalidURIError
      nil
    end
    private_class_method :parse
  end
end
