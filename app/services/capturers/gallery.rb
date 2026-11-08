module Capturers
  # A post with photos or a carousel, through gallery-dl: every file of the post and gallery-dl's
  # per-file metadata sidecars in one ZIP (original), plus a normalized post record (metadata).
  class Gallery < Base
    def call
      FileUtils.mkdir_p(path("post"))
      command = [ "gallery-dl", "--write-metadata", "--directory", path("post"), "--quiet" ]
      command += [ "--cookies", ENV["YTDLP_COOKIES_FILE"] ] if ENV["YTDLP_COOKIES_FILE"].present?
      command += [ "--proxy", ENV["YTDLP_PROXY"] ] if ENV["YTDLP_PROXY"].present?
      command << "--" << url
      run!(*command, env: { "HOME" => workdir })

      files = Dir.glob(path("post/**/*")).select { |f| ::File.file?(f) }.sort
      raise ToolFailed, "gallery-dl downloaded nothing" if files.empty?

      media = files.reject { |f| f.end_with?(".json") }
      sidecars = files.select { |f| f.end_with?(".json") }
      total = files.sum { |f| ::File.size(f) }
      raise TooLarge, "the post is #{total} bytes; the limit is #{Capturers.max_bytes}" if total > Capturers.max_bytes

      write_json("post.json", normalize(media, sidecars))
      Zip::File.open(path("post.zip"), create: true) do |zip|
        files.each { |f| zip.add(f.delete_prefix(path("post") + "/"), f) }
      end
      FileUtils.rm_rf(path("post"))

      [
        output("original", "post.zip", content_type: "application/zip"),
        output("metadata", "post.json", content_type: "application/json")
      ]
    end

    private

    # The fields that every gallery-dl extractor fills in, from the first sidecar, plus the files.
    def normalize(media, sidecars)
      first = sidecars.first ? JSON.parse(::File.read(sidecars.first)) : {}
      {
        "url" => url,
        "captured_at" => Time.current.iso8601,
        "author" => first["username"] || first["author"]&.dig("name") || first["uploader"] || first["owner"],
        "caption" => first["description"] || first["content"] || first["title"] || first["caption"],
        "posted_at" => first["date"],
        "likes" => first["likes"] || first["favorite_count"] || first["like_count"],
        "files" => media.map { |f| f.delete_prefix(path("post") + "/") }
      }
    rescue JSON::ParserError
      { "url" => url, "files" => media.map { |f| f.delete_prefix(path("post") + "/") } }
    end
  end
end
