require "net/http"

module Capturers
  # One HTTP GET to a file, with redirects, a size cap and a timeout. Used by the document and file
  # capturers and by the probe. Never sends a cookie or a credential.
  module Download
    MAX_REDIRECTS = 5
    OPEN_TIMEOUT = 15
    READ_TIMEOUT = 60
    USER_AGENT = "Stash/1.0 (+https://stash.patchworklabs.org; archive)".freeze

    Fetched = Data.define(:uri, :content_type, :filename, :path, :byte_size)

    # Downloads the URL into `to`. Returns a Fetched. Raises TooLarge past the cap, ToolFailed on an
    # HTTP error.
    def self.fetch(url, to:, max_bytes: Capturers.max_bytes)
      uri = URI.parse(url)
      MAX_REDIRECTS.times do
        request = Net::HTTP::Get.new(uri)
        request["User-Agent"] = USER_AGENT
        request["Accept"] = "*/*"
        result = nil
        start(uri) do |http|
          http.request(request) do |response|
            case response
            when Net::HTTPRedirection
              uri = URI.join(uri, response["location"])
              next
            when Net::HTTPSuccess
              length = response["content-length"].to_i
              raise TooLarge, "the server says #{length} bytes; the limit is #{max_bytes}" if length > max_bytes

              size = 0
              ::File.open(to, "wb") do |file|
                response.read_body do |chunk|
                  size += chunk.bytesize
                  raise TooLarge, "the download passed #{max_bytes} bytes" if size > max_bytes

                  file.write(chunk)
                end
              end
              result = Fetched.new(uri: uri, content_type: content_type_of(response), filename: filename_of(response, uri),
                path: to, byte_size: size)
            else
              raise ToolFailed, "GET #{uri.host} answered #{response.code}"
            end
          end
        end
        return result if result
      end
      raise ToolFailed, "too many redirects"
    rescue SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError => e
      raise ToolFailed, "could not fetch #{uri&.host}: #{e.class}"
    end

    # The Content-Type a HEAD request answers with, or nil when the server does not answer.
    # Some servers refuse HEAD; those get a GET for the headers only.
    def self.content_type(url)
      uri = URI.parse(url)
      MAX_REDIRECTS.times do
        response = start(uri) do |http|
          head = Net::HTTP::Head.new(uri)
          head["User-Agent"] = USER_AGENT
          answer = http.request(head)
          if answer.is_a?(Net::HTTPMethodNotAllowed) || answer.is_a?(Net::HTTPNotImplemented)
            get = Net::HTTP::Get.new(uri)
            get["User-Agent"] = USER_AGENT
            get["Range"] = "bytes=0-0"
            answer = http.request(get) { |r| break r }
          end
          answer
        end
        if response.is_a?(Net::HTTPRedirection)
          uri = URI.join(uri, response["location"])
          next
        end
        return content_type_of(response)
      end
      nil
    rescue StandardError
      nil
    end

    def self.start(uri, &)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
        open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT, &)
    end

    def self.content_type_of(response)
      response["content-type"].to_s.split(";").first.to_s.strip.downcase.presence || "application/octet-stream"
    end

    def self.filename_of(response, uri)
      disposition = response["content-disposition"].to_s
      if (match = disposition.match(/filename\*=(?:UTF-8'')?"?([^";]+)"?/i) || disposition.match(/filename="?([^";]+)"?/i))
        return sanitize(CGI.unescape(match[1]))
      end

      sanitize(::File.basename(uri.path).presence || "download")
    end

    def self.sanitize(name)
      name.gsub(/[^\w.\- ]+/, "_").squeeze("_").first(200).presence || "download"
    end
  end
end
