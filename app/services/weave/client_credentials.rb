module Weave
  # Stash's own client_credentials access tokens from Weave, one per scope.
  #
  # Stash asks `POST {WEAVE_ISSUER}/oauth/token` with grant_type=client_credentials and HTTP Basic
  # auth as its own Weave app. Weave gives the token only when Stash's app is allowed the scope.
  #
  # Tokens are kept in this process only, never in Rails.cache, because a token is a secret. The
  # key is the issuer, the client id and the scope. A token is used until EXPIRY_MARGIN before
  # Weave says it expires. Errors are never cached. Never log a token.
  class ClientCredentials
    include Http

    PATH = "/oauth/token".freeze
    EXPIRY_MARGIN = 30.seconds
    # Used when Weave's answer has no usable expires_in.
    DEFAULT_LIFETIME = 5.minutes

    @tokens = {}
    @lock = Monitor.new

    class << self
      def clear_cache!
        @lock.synchronize { @tokens.clear }
      end

      def cached(key)
        @lock.synchronize do
          entry = @tokens[key]
          return entry[:token] if entry && entry[:refresh_at] > Time.current

          entry = yield
          @tokens[key] = entry
          entry[:token]
        end
      end

      def forget(key)
        @lock.synchronize { @tokens.delete(key) }
      end
    end

    # Returns an access token for the scope. Raises UnavailableError when Weave does not answer,
    # or refuses Stash's credentials or the scope.
    def token(scope)
      self.class.cached(cache_key(scope)) { fetch(scope) }
    end

    # Drops the cached token, for example after Weave answered 401 to it.
    def forget(scope)
      self.class.forget(cache_key(scope))
    end

    private

    def cache_key(scope)
      [ Config.issuer, Config.client_id, scope ]
    end

    def fetch(scope)
      uri = URI("#{Config.issuer}#{PATH}")
      request = Net::HTTP::Post.new(uri.request_uri)
      request.basic_auth(Config.client_id, Config.client_secret)
      request.set_form_data(grant_type: "client_credentials", scope: scope)
      response = http_for(uri) { |http| http.request(request) }
      # 400, 401 and 403 usually mean that Stash's app in Weave is not allowed the scope.
      unless response.code == "200"
        raise UnavailableError, "Weave refused Stash a client_credentials token for the scope #{scope} " \
          "(#{response.code}). Allow the scope on the Stash app in Weave."
      end

      body = parse_json(response.body)
      token = body["access_token"]
      raise UnavailableError, "Weave's token answer has no access_token" unless token.is_a?(String) && token.present?

      lifetime = body["expires_in"].is_a?(Integer) ? body["expires_in"].seconds : DEFAULT_LIFETIME
      { token: token, refresh_at: Time.current + [ lifetime - EXPIRY_MARGIN, 0.seconds ].max }
    end
  end
end
