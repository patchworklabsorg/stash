require "net/http"

module Weave
  # The HTTP helpers that every Weave client in this namespace shares: short timeouts, and
  # network failures and malformed JSON become UnavailableError.
  module Http
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 10

    private

    def http_for(uri, &)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
        open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT, &)
    rescue SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, Net::HTTPBadResponse => e
      raise UnavailableError, "could not reach Weave at #{uri.host}: #{e.class}"
    end

    def parse_json(body)
      value = JSON.parse(body.to_s)
      raise UnavailableError, "Weave answered with JSON that is not an object" unless value.is_a?(Hash)

      value
    rescue JSON::ParserError
      raise UnavailableError, "Weave answered with malformed JSON"
    end
  end
end
