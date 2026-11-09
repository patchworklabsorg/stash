require "mail"
require "base64"
require "uri"
require "nokogiri"

module Capturers
  # Turns the MHTML that Chromium saved into one HTML file that a browser can show: every
  # resource the MHTML carries (styles, images) is inlined as a data URL, every link is made
  # absolute and opens in a new tab, and everything that could reach the network or run is
  # taken out. The result is the `view` artifact, shown on the archive page in a sandboxed frame
  # with scripts off and no network. The document is parsed (Nokogiri's HTML5 parser) and
  # rewritten node by node, never with regular expressions over the markup, so an odd attribute
  # cannot slip a tag past the rewrite.
  #
  # Chromium's MHTML leaves two things out: web fonts, and what was drawn on a <canvas>. The
  # capturer passes those in: `resources` are the responses it saw on the network (fonts and
  # images the MHTML lacks), `canvases` the PNG data URL of each canvas in document order, which
  # replaces the canvas with an <img>.
  #
  # MHTML is MIME multipart/related: the first part is the document, the others its resources,
  # each with a Content-Location (its URL) and base64 or quoted-printable content.
  module Mhtml
    # Attributes whose value is one URL to inline, on any element but a link.
    URL_ATTRIBUTES = %w[src href poster background data].freeze
    # <link rel> values that make the browser touch the network for nothing the copy needs.
    NETWORK_HINTS = %w[preconnect dns-prefetch prefetch prerender preload modulepreload].freeze
    # <meta http-equiv> values that navigate, loosen or leak.
    META_EQUIVS = %w[refresh content-security-policy x-dns-prefetch-control].freeze
    # The resources the view inlines once, however often the page references them.
    MAX_PART_BYTES = 10.megabytes

    Part = Data.define(:location, :content_type, :body)

    class Inliner
      def initialize(location, resources)
        @resources = resources
        @data_urls = {}
        @base = location
      end

      def call(html, canvases)
        doc = Nokogiri::HTML5.parse(html, @base, "UTF-8")
        take_base(doc)
        remove_active_parts(doc)
        replace_canvases(doc, canvases)
        rewrite_links(doc)
        rewrite_resources(doc)
        rewrite_styles(doc)
        note(doc)
        doc.to_html
      end

      private

      # The page's own <base> moves the resolution base; the view gets one of its own.
      def take_base(doc)
        if (own = doc.at_css("base[href]"))
          @base = absolute(own["href"], @base)
        end
        doc.css("base").each(&:remove)
      end

      # Scripts never run in the frame, so they only add weight. The metas and link hints could
      # navigate the frame or make the browser call the archived site's hosts; the copy has to be
      # silent. Event handler attributes are blocked by the policy too; drop them anyway.
      def remove_active_parts(doc)
        doc.css("script, noscript > script").each(&:remove)
        doc.css("meta").each do |meta|
          equiv = meta["http-equiv"].to_s.strip.downcase
          name = meta["name"].to_s.strip.downcase
          meta.remove if META_EQUIVS.include?(equiv) || name == "referrer"
        end
        doc.css("link").each do |link|
          rels = link["rel"].to_s.downcase.split
          link.remove if rels.intersect?(NETWORK_HINTS)
        end
        doc.css("*").each do |node|
          node.attribute_nodes.each { |attribute| attribute.remove if attribute.name.start_with?("on") }
          node.remove_attribute("ping")
        end
      end

      # Each <canvas>, in document order, becomes an <img> of what was drawn on it. A canvas
      # with no image (tainted, or WebGL without a kept buffer) stays as it is, empty.
      def replace_canvases(doc, canvases)
        doc.css("canvas").each_with_index do |canvas, index|
          data = canvases[index].to_s
          next unless data.start_with?("data:image/")

          img = doc.create_element("img", src: data, alt: "")
          %w[id class style width height].each { |name| img[name] = canvas[name] if canvas[name] }
          canvas.attribute_nodes.each { |a| img[a.name] = a.value if a.name.start_with?("aria-") }
          canvas.replace(img)
        end
      end

      # A person's link: absolute, in a new tab, no referrer, never a data URL. A fragment stays
      # a fragment, so it scrolls the copy. The sandboxed frame has no scripts and no same-origin
      # rights, so these links are the one way out of it.
      def rewrite_links(doc)
        doc.css("a, area").each do |link|
          href = link["href"].to_s.strip
          unless href.empty? || href.start_with?("#")
            link["href"] = absolute(href, @base)
            link.remove_attribute("href") if link["href"].match?(/\A(javascript|data|blob|vbscript):/i)
          end
          link["target"] = "_blank"
          link["rel"] = "noopener noreferrer nofollow"
        end
      end

      def rewrite_resources(doc)
        doc.css("*").each do |node|
          next if %w[a area base].include?(node.name)

          URL_ATTRIBUTES.each do |name|
            node[name] = resolve(node[name]) if node[name]
          end
          node["srcset"] = rewrite_srcset(node["srcset"]) if node["srcset"]
          node["style"] = rewrite_css(node["style"]) if node["style"]
        end
      end

      def rewrite_styles(doc)
        doc.css("style").each { |style| style.content = rewrite_css(style.content) }
      end

      # The srcset grammar: candidates separated by a comma and whitespace, each a URL and an
      # optional descriptor. A data URL carries commas of its own, so the split is on ", " only
      # after a descriptor or at a candidate boundary, never inside a URL.
      def rewrite_srcset(value)
        value.strip.split(/,\s+(?=\S)/).map do |candidate|
          url, descriptor = candidate.strip.split(/\s+/, 2)
          [ resolve(url.to_s), descriptor ].compact.join(" ")
        end.join(", ")
      end

      def rewrite_css(css, base: @base, depth: 0)
        return css.to_s if depth > 3 || css.nil?

        # Linear patterns: a hostile stylesheet full of `url(` must not stall the capture. The value
        # may not hold a quote or a parenthesis, so a second `url(` ends the attempt at once.
        css = css.gsub(/url\(\s*(["']?)([^"'()]*)\1\s*\)/i) do
          quote, value = Regexp.last_match(1), Regexp.last_match(2)
          "url(#{quote}#{resolve(value, base: base, depth: depth)}#{quote})"
        end
        css.gsub(/@import\s+(["'])([^"']*)\1/i) do
          quote, value = Regexp.last_match(1), Regexp.last_match(2)
          "@import #{quote}#{resolve(value, base: base, depth: depth)}#{quote}"
        end
      end

      # The data URL of the resource at `value`, or its absolute URL when nothing was captured
      # (the policy then blocks it, and the element falls back). HTML attributes carry `&amp;`
      # where the URL has `&`; Nokogiri gives the decoded value, so nothing to undo here.
      def resolve(value, base: @base, depth: 0)
        value = value.to_s.strip
        return value if value.empty? || value.start_with?("data:", "#", "about:", "javascript:", "blob:", "cid:")

        url = absolute(value, base)
        part = @resources[url] || @resources[value]
        return url unless part
        return url if part.body.bytesize > MAX_PART_BYTES

        @data_urls[part] ||= begin
          body = part.body
          body = rewrite_css(body.dup.force_encoding("UTF-8").scrub, base: part.location, depth: depth + 1) if part.content_type == "text/css"
          "data:#{part.content_type};base64,#{Base64.strict_encode64(body)}"
        end
      end

      def absolute(value, base)
        return value if base.to_s.empty?

        URI.join(base, URI::RFC2396_PARSER.escape(value.to_s.strip)).to_s
      rescue URI::Error
        value
      end

      def note(doc)
        text = " Archived by Stash. A copy of #{@base.to_s.gsub("--", "%2D%2D")}; styles and images are inlined, scripts are removed and do not run. "
        comment = Nokogiri::XML::Comment.new(doc, text)
        if (head = doc.at_css("head"))
          head.prepend_child(comment)
        else
          doc.root&.prepend_child(comment)
        end
      end
    end

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
      html = document.body.dup.force_encoding("UTF-8").scrub
      Inliner.new(document.location, known).call(html, canvases)
    rescue Mail::Field::ParseError, ArgumentError, EncodingError => e
      raise ToolFailed, "the MHTML could not be read: #{e.class}"
    end

    def part_from(part)
      location = part.header["Content-Location"]&.value.to_s.strip
      type = part.content_type.to_s.split(";").first.to_s.strip.downcase
      return nil if location.empty? && !type.start_with?("text/html")

      Part.new(location: location, content_type: type, body: part.decoded.to_s)
    end
  end
end
