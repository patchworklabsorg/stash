require "mail"
require "base64"
require "uri"

module Capturers
  # Turns the MHTML that Chromium saved into one HTML file that a browser can show: every
  # resource the MHTML carries (styles, images) is inlined as a data URL, and every link is made
  # absolute and opens in a new tab. The result is the `view` artifact, shown on the archive page
  # in a sandboxed frame with scripts off and no network. Scripts are left in place but never run
  # there, so a page that draws itself with JavaScript shows the DOM as captured.
  #
  # Chromium's MHTML leaves two things out: web fonts, and what was drawn on a <canvas>. The
  # capturer passes those in: `resources` are the responses it saw on the network (fonts and
  # images the MHTML lacks), `canvases` the PNG data URL of each canvas in document order, which
  # replaces the canvas with an <img>.
  #
  # MHTML is MIME multipart/related: the first part is the document, the others its resources,
  # each with a Content-Location (its URL) and base64 or quoted-printable content.
  module Mhtml
    # Attributes whose value is one URL to inline.
    URL_ATTRIBUTES = %w[src href poster background].freeze

    Part = Data.define(:location, :content_type, :body)

    module_function

    # Reads the MHTML file and returns the HTML string. Raises ToolFailed when the file is not
    # MHTML or has no document part. `resources` is { url => Part } for what the MHTML lacks;
    # a part in the MHTML wins. `canvases` is the data URL (or nil) of each <canvas>, in order.
    def inline(path, resources: {}, canvases: [])
      message = Mail.read_from_string(::File.binread(path))
      parts = message.multipart? ? message.parts : [ message ]
      parts = parts.map { |part| part_from(part) }.compact
      document = parts.find { |part| part.content_type.start_with?("text/html") }
      raise ToolFailed, "the MHTML has no HTML part" unless document

      known = resources.merge(parts.reject { |part| part.equal?(document) }.to_h { |part| [ part.location, part ] })
      base = document.location
      html = document.body.dup.force_encoding("UTF-8").scrub
      html = replace_canvases(html, canvases)
      html = rewrite_html(html, base, known)
      inject_base_and_meta(html, base)
    rescue Mail::Field::ParseError, ArgumentError, EncodingError => e
      raise ToolFailed, "the MHTML could not be read: #{e.class}"
    end

    def part_from(part)
      location = part.header["Content-Location"]&.value.to_s.strip
      type = part.content_type.to_s.split(";").first.to_s.strip.downcase
      return nil if location.empty? && !type.start_with?("text/html")

      Part.new(location: location, content_type: type, body: part.decoded.to_s)
    end

    # Each <canvas>, in document order, becomes an <img> of what was drawn on it. A canvas
    # with no image (tainted, or WebGL without a kept buffer) stays as it is, empty.
    def replace_canvases(html, canvases)
      index = -1
      html.gsub(%r{<canvas\b([^>]*)>.*?</canvas>}mi) do
        index += 1
        attributes, data = Regexp.last_match(1), canvases[index]
        next Regexp.last_match(0) unless data.to_s.start_with?("data:image/")

        # Keep the attributes that place and size the element; drop the rest.
        kept = attributes.to_enum(:scan, /\s(?:id|class|style|width|height|aria-[a-z-]+)=(["'])(?:(?!\1).)*\1/i)
                         .map { Regexp.last_match(0) }.join
        "<img src=\"#{data}\" alt=\"\"#{kept}>"
      end
    end

    # Resolves every resource URL in the document and in its inline styles to a data URL.
    def rewrite_html(html, base, resources)
      html = html.gsub(/<(a|area)\b([^>]*)>/i) do
        tag, attributes = Regexp.last_match(1), Regexp.last_match(2)
        "<#{tag}#{link_attributes(attributes, base)}>"
      end
      html = html.gsub(/\b(#{URL_ATTRIBUTES.join("|")})=("|')(.*?)\2/i) do
        attribute, quote, value = Regexp.last_match(1), Regexp.last_match(2), Regexp.last_match(3)
        "#{attribute}=#{quote}#{resolve(value, base, resources)}#{quote}"
      end
      html = html.gsub(/\bsrcset=("|')(.*?)\1/i) do
        quote, value = Regexp.last_match(1), Regexp.last_match(2)
        candidates = value.split(",").map do |candidate|
          url, descriptor = candidate.strip.split(/\s+/, 2)
          [ resolve(url.to_s, base, resources), descriptor ].compact.join(" ")
        end
        "srcset=#{quote}#{candidates.join(", ")}#{quote}"
      end
      html = html.gsub(/\bstyle=("|')(.*?)\1/i) do
        quote, css = Regexp.last_match(1), Regexp.last_match(2)
        "style=#{quote}#{rewrite_css(css, base, resources)}#{quote}"
      end
      html.gsub(%r{<style\b[^>]*>(.*?)</style>}mi) do
        tag, css = Regexp.last_match(0), Regexp.last_match(1)
        css.empty? ? tag : tag.sub(css) { rewrite_css(css, base, resources) }
      end
    end

    # A person's link: absolute, in a new tab, no referrer. The sandboxed frame has no scripts
    # and no same-origin rights, so this is the one way out of it.
    def link_attributes(attributes, base)
      attributes = attributes.gsub(/\s(target|rel)=("|')(.*?)\2/i, "")
      attributes = attributes.sub(/\bhref=("|')(.*?)\1/i) do
        quote, value = Regexp.last_match(1), Regexp.last_match(2)
        "href=#{quote}#{absolute(value, base)}#{quote}"
      end
      "#{attributes} target=\"_blank\" rel=\"noopener noreferrer nofollow\""
    end

    def rewrite_css(css, base, resources, depth: 0)
      return css if depth > 3

      # The quote group always takes part (it may be empty), so the backreference matches an
      # unquoted url() too.
      css.gsub(/url\(\s*(["']?)(.*?)\1\s*\)/i) do
        quote, value = Regexp.last_match(1), Regexp.last_match(2)
        "url(#{quote}#{resolve(value, base, resources, depth: depth)}#{quote})"
      end.gsub(/@import\s+("|')(.*?)\1/i) do
        quote, value = Regexp.last_match(1), Regexp.last_match(2)
        "@import #{quote}#{resolve(value, base, resources, depth: depth)}#{quote}"
      end
    end

    # The data URL of the resource at `value`, or the absolute URL when nothing was captured.
    # HTML attributes carry `&amp;` where the URL has `&`.
    def resolve(value, base, resources, depth: 0)
      value = value.to_s.strip
      return value if value.empty? || value.start_with?("data:", "#", "about:", "javascript:", "blob:")

      url = absolute(value.gsub("&amp;", "&"), base)
      part = resources[url] || resources[value]
      return url unless part

      body = part.body
      body = rewrite_css(body.dup.force_encoding("UTF-8").scrub, part.location, resources, depth: depth + 1) if part.content_type == "text/css"
      "data:#{part.content_type};base64,#{Base64.strict_encode64(body)}"
    end

    def absolute(value, base)
      return value if base.to_s.empty?

      URI.join(base, value.to_s.strip).to_s
    rescue URI::Error
      value
    end

    # A <base> for the links the rewrite missed, and a note of what this is.
    def inject_base_and_meta(html, base)
      safe_base = base.to_s.gsub(/["<>]/, '"' => "&quot;", "<" => "%3C", ">" => "%3E").gsub("--", "%2D%2D")
      head = "<!-- Archived by Stash. A copy of #{safe_base}; styles and images are inlined, scripts do not run. -->\n"
      head += "<base href=\"#{safe_base}\" target=\"_blank\">\n" if base.present? && html !~ /<base\b/i
      if (index = html =~ /<head\b[^>]*>/i)
        html.dup.insert(index + Regexp.last_match(0).length, "\n#{head}")
      else
        head + html
      end
    end
  end
end
