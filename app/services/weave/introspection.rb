module Weave
  # Checks a patch app's bearer token with Weave's token introspection (RFC 7662).
  #
  # A patch app gets a client_credentials token from Weave with scope `stash`. Stash posts it to
  # `POST {WEAVE_ISSUER}/oauth/introspect`, with HTTP Basic auth as its own Weave app. Weave lets
  # an app with the `introspect` scope introspect other apps' client_credentials tokens.
  #
  # Answers are cached for TTL, but never past the token's `exp`. The cache key is a SHA-256 of
  # the token, so the raw token never reaches the cache. Errors are never cached: when Weave is
  # down, the next request asks again. Never log the token.
  class Introspection
    include Http

    PATH = "/oauth/introspect".freeze
    TTL = 60.seconds
    CACHE_PREFIX = "weave:introspection:".freeze

    # What Weave said about a token. `scopes` is a list. `exp` is a Unix time, or nil.
    Result = Data.define(:active, :client_id, :scopes, :exp) do
      def self.inactive
        new(active: false, client_id: nil, scopes: [], exp: nil)
      end

      def active?(now = Time.current)
        active && (exp.nil? || exp > now.to_i)
      end

      def scope?(scope)
        scopes.include?(scope)
      end
    end

    def self.cache_key(token)
      "#{CACHE_PREFIX}#{Digest::SHA256.hexdigest(token)}"
    end

    def initialize(cache: Rails.cache)
      @cache = cache
    end

    # Returns a Result. Raises UnavailableError when Weave does not answer, answers with an
    # error, or refuses Stash's own client credentials.
    def call(token)
      return Result.inactive if token.blank?

      key = self.class.cache_key(token)
      cached = @cache.read(key)
      return result_from(cached) if cached.is_a?(Hash)

      answer = introspect(token)
      ttl = ttl_for(answer)
      @cache.write(key, answer, expires_in: ttl) if ttl
      result_from(answer)
    end

    private

    def introspect(token)
      uri = URI("#{Config.issuer}#{PATH}")
      request = Net::HTTP::Post.new(uri.request_uri)
      request.basic_auth(Config.client_id, Config.client_secret)
      request.set_form_data(token: token, token_type_hint: "access_token")
      response = http_for(uri) { |http| http.request(request) }
      # A 401 or 403 means Weave refused Stash's own credentials or its introspect scope. That is
      # Stash's problem, not the patch app's, so the patch app gets a 503 and retries.
      unless response.code == "200"
        raise UnavailableError, "Weave's introspection endpoint answered #{response.code}"
      end

      normalize(parse_json(response.body))
    end

    # Keeps only the fields Stash uses, in a form that is safe to cache.
    def normalize(body)
      {
        "active" => body["active"] == true,
        "client_id" => body["client_id"].is_a?(String) ? body["client_id"] : nil,
        "scopes" => body["scope"].is_a?(String) ? body["scope"].split : [],
        "exp" => body["exp"].is_a?(Integer) ? body["exp"] : nil
      }
    end

    # nil means "do not cache": the token has expired already.
    def ttl_for(answer)
      ttl = TTL.to_i
      ttl = [ ttl, answer["exp"] - Time.current.to_i ].min if answer["exp"]
      ttl.positive? ? ttl : nil
    end

    def result_from(answer)
      Result.new(active: answer["active"] == true, client_id: answer["client_id"],
        scopes: Array(answer["scopes"]), exp: answer["exp"])
    end
  end
end
