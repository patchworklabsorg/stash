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

    def google(kind, id)
      export = GOOGLE_EXPORTS.fetch(kind)
      native = Download.fetch(google_export_url(kind, id, export[:native]), to: path("document.#{export[:native]}"))
      log("Google export: #{native.byte_size} bytes as #{export[:native]}")
      pdf = Download.fetch(google_export_url(kind, id, "pdf"), to: path("document.pdf"))
      log("Google export: #{pdf.byte_size} bytes as pdf")
      [
        output("original", "document.#{export[:native]}", content_type: export[:type], filename: "#{id}.#{export[:native]}"),
        output("rendition", "document.pdf", content_type: "application/pdf", filename: "#{id}.pdf")
      ]
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
