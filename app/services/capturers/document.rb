module Capturers
  # A presentation, document or spreadsheet: the file as served (original) and a PDF of it
  # (rendition).
  #
  # Google Docs, Slides, Sheets and Drawings export through their public export URLs, so only a
  # document that is shared with "anyone with the link" can be archived. Any other URL is
  # downloaded as is. A file that is not a PDF is converted with LibreOffice.
  class Document < Base
    GOOGLE_EXPORTS = {
      "document" => { native: "docx", pdf: "pdf", type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document" },
      "presentation" => { native: "pptx", pdf: "pdf", type: "application/vnd.openxmlformats-officedocument.presentationml.presentation" },
      "spreadsheets" => { native: "xlsx", pdf: "pdf", type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" },
      "drawings" => { native: "svg", pdf: "pdf", type: "image/svg+xml" }
    }.freeze
    CONVERT_TIMEOUT = 5.minutes

    def call
      if (kind, id = Router.google_document(url))
        google(kind, id)
      else
        direct
      end
    end

    private

    GOOGLE_NAMES = { "document" => "Google Doc", "presentation" => "Google Slides deck",
                     "spreadsheets" => "Google Sheet", "drawings" => "Google Drawing" }.freeze

    def google(kind, id)
      export = GOOGLE_EXPORTS.fetch(kind)
      native = google_export(kind, id, export[:native], export[:type])
      log("Google export: #{native.byte_size} bytes as #{export[:native]}")
      pdf = google_export(kind, id, "pdf", "application/pdf")
      log("Google export: #{pdf.byte_size} bytes as pdf")
      [
        output("original", "document.#{export[:native]}", content_type: export[:type], filename: "#{id}.#{export[:native]}"),
        output("rendition", "document.pdf", content_type: "application/pdf", filename: "#{id}.pdf")
      ]
    end

    # One Google export. A document that is not shared with anyone with the link answers 404,
    # or 401, or a 302 to the Google sign-in page (a 200 of HTML on another host), the same as
    # one that does not exist. Every one of those is NotPublic: the owner has to act. A 429
    # stays Blocked: Google is rate limiting, and later works.
    def google_export(kind, id, format, expected_type)
      fetched =
        begin
          Download.fetch(google_export_url(kind, id, format), to: path("document.#{format}"))
        rescue NotFound, NotPublic => e
          raise not_shared(kind, e.http_status)
        rescue Blocked => e
          raise not_shared(kind, e.http_status) if e.http_status == 403

          raise
        end
      served = fetched.content_type.to_s
      if fetched.uri.host != "docs.google.com" || Router::HTML_TYPES.include?(served) || !served.start_with?(expected_type)
        log("Google export answered #{served} from #{fetched.uri.host}, not the #{format}")
        raise not_shared(kind, "a sign-in page")
      end
      fetched
    end

    def not_shared(kind, answer)
      error = NotPublic.new("Google answered #{answer} for the #{GOOGLE_NAMES.fetch(kind)}: " \
                            "it is not shared with anyone with the link, or it does not exist. " \
                            "Ask the owner to share it, then run the archive again.")
      error.http_status = answer if answer.is_a?(Integer)
      error
    end

    def google_export_url(kind, id, format)
      case kind
      when "presentation", "drawings" then "https://docs.google.com/#{kind}/d/#{id}/export/#{format}"
      else "https://docs.google.com/#{kind}/d/#{id}/export?format=#{format}"
      end
    end

    def direct
      fetched = Download.fetch(url, to: path("document"))
      log("downloaded #{fetched.byte_size} bytes, #{fetched.content_type}, #{fetched.filename}")
      raise Skip, "the URL serves HTML, not a document" if Router::HTML_TYPES.include?(fetched.content_type)

      extension = ::File.extname(fetched.filename).delete_prefix(".").presence || extension_for(fetched.content_type)
      original = "document.#{extension}"
      ::File.rename(path("document"), path(original))
      outputs = [ output("original", original, content_type: fetched.content_type, filename: fetched.filename) ]

      if fetched.content_type == "application/pdf" || extension == "pdf"
        return outputs
      end

      log("LibreOffice: converting to PDF")
      run!("soffice", "--headless", "--norestore", "--convert-to", "pdf", "--outdir", workdir, path(original),
        timeout: CONVERT_TIMEOUT, env: { "HOME" => workdir })
      pdf = path("document.pdf")
      raise ToolFailed, "LibreOffice made no PDF" unless ::File.exist?(pdf)

      outputs << output("rendition", "document.pdf", content_type: "application/pdf",
        filename: "#{::File.basename(fetched.filename, ".*")}.pdf")
    end

    def extension_for(content_type)
      Router::DOCUMENT_TYPES.include?(content_type) ? Marcel::Magic.new(content_type).extensions.first.to_s.presence || "bin" : "bin"
    end
  end
end
