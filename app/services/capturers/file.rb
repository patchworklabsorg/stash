module Capturers
  # Any other file: the bytes as served (original). An HTML answer is a page, not a file, so it
  # is skipped here and the page capturer has it.
  class File < Base
    def call
      fetched = Download.fetch(url, to: path("file"))
      log("downloaded #{fetched.byte_size} bytes, #{fetched.content_type}, #{fetched.filename}")
      raise Skip, "the URL serves HTML, not a file" if Router::HTML_TYPES.include?(fetched.content_type)

      [ output("original", "file", content_type: fetched.content_type, filename: fetched.filename) ]
    end
  end
end
