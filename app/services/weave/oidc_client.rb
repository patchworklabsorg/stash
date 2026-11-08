module Weave
  # A small OIDC client for Weave: Authorization Code flow with PKCE (S256).
  #
  # It fetches Weave's discovery document and JWKS, builds the authorization URL,
  # exchanges the code for tokens, and verifies the id_token: RS256 signature against
  # the JWKS, `iss`, `aud`, `exp`, `iat` and `nonce`. The roles come from the
  # `roles` claim in the id_token.
  #
  # The roles in the session are for display and for reading pages. A person's action
  # that moves money (approving a top-up) re-checks the person live with Weave::Directory.
  class OidcClient
    include Http

    SCOPES = "openid profile email roles".freeze
    # Discovery and JWKS answers are kept this long in each process.
    CACHE_TTL = 1.hour

    Identity = Data.define(:sub, :name, :email, :roles)

    @cache = {}
    @cache_lock = Monitor.new

    class << self
      # Process-wide cache for the discovery document and the JWKS.
      def cached(key, refresh: false)
        @cache_lock.synchronize do
          entry = @cache[key]
          if refresh || entry.nil? || entry[:expires_at] <= Time.current
            entry = { value: yield, expires_at: Time.current + CACHE_TTL }
            @cache[key] = entry
          end
          entry[:value]
        end
      end

      def clear_cache!
        @cache_lock.synchronize { @cache.clear }
      end
    end

    # A random value for `state`, `nonce` and the PKCE code verifier.
    def self.random_token
      SecureRandom.urlsafe_base64(32)
    end

    def self.code_challenge(code_verifier)
      Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false)
    end

    def authorization_url(state:, nonce:, code_verifier:, redirect_uri:)
      query = {
        response_type: "code",
        client_id: Config.client_id,
        redirect_uri: redirect_uri,
        scope: SCOPES,
        state: state,
        nonce: nonce,
        code_challenge: self.class.code_challenge(code_verifier),
        code_challenge_method: "S256"
      }
      "#{discovery.fetch("authorization_endpoint")}?#{query.to_query}"
    end

    def exchange_code(code:, code_verifier:, redirect_uri:, nonce:)
      response = post_form(
        discovery.fetch("token_endpoint"),
        grant_type: "authorization_code",
        code: code,
        redirect_uri: redirect_uri,
        client_id: Config.client_id,
        client_secret: Config.client_secret,
        code_verifier: code_verifier
      )
      raise UnavailableError, "Weave's token endpoint answered #{response.code}" if response.code.to_i >= 500
      raise AuthError, "Weave refused the code (#{response.code})" unless response.code == "200"

      id_token = parse_json(response.body)["id_token"]
      raise AuthError, "Weave's token answer has no id_token" unless id_token.is_a?(String)

      verify_id_token(id_token, nonce: nonce)
    end

    def verify_id_token(id_token, nonce:)
      claims, _header = JWT.decode(
        id_token, nil, true,
        algorithms: [ "RS256" ],
        jwks: method(:jwks_for),
        iss: Config.issuer, verify_iss: true,
        aud: Config.client_id, verify_aud: true,
        verify_iat: true,
        required_claims: %w[sub iss aud exp iat nonce]
      )
      unless ActiveSupport::SecurityUtils.secure_compare(claims["nonce"].to_s, nonce.to_s)
        raise AuthError, "id_token nonce does not match"
      end

      sub = claims["sub"]
      raise AuthError, "id_token has no sub" unless sub.is_a?(String) && sub.present?

      Identity.new(
        sub: sub,
        name: claims["name"].is_a?(String) ? claims["name"] : "",
        email: claims["email"].is_a?(String) ? claims["email"] : "",
        roles: Roles.from_claim(claims["roles"])
      )
    rescue JWT::DecodeError => e
      raise AuthError, "id_token is not valid: #{e.message}"
    end

    private

    def discovery
      self.class.cached([ :discovery, Config.issuer ]) do
        get_json("#{Config.issuer}/.well-known/openid-configuration")
      end
    end

    # The JWKS loader for JWT.decode. On an unknown key id it fetches the JWKS again once,
    # so a key rotation in Weave does not break sign-in.
    def jwks_for(options)
      refresh = options[:kid_not_found] == true
      self.class.cached([ :jwks, Config.issuer ], refresh: refresh) do
        get_json(discovery.fetch("jwks_uri"))
      end
    end

    def get_json(url)
      uri = URI(url)
      response = http_for(uri) { |http| http.get(uri.request_uri) }
      raise UnavailableError, "Weave answered #{response.code} for #{url}" unless response.code == "200"

      parse_json(response.body)
    end

    def post_form(url, params)
      uri = URI(url)
      request = Net::HTTP::Post.new(uri.request_uri)
      request.set_form_data(params)
      http_for(uri) { |http| http.request(request) }
    end
  end
end
