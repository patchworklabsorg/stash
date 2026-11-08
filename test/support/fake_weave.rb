# Stubs Weave's OIDC, introspection, client_credentials and directory endpoints with WebMock and signs id_tokens with a test RSA key.
module FakeWeave
  ISSUER = "https://weave.test".freeze
  CLIENT_ID = "stash-test-client".freeze
  KEY = OpenSSL::PKey::RSA.generate(2048)
  JWK = JWT::JWK.new(KEY, kid: "test-key-1")

  def fake_weave_env
    { "WEAVE_ISSUER" => ISSUER, "WEAVE_CLIENT_ID" => CLIENT_ID, "WEAVE_CLIENT_SECRET" => "test-secret" }
  end

  def with_fake_weave(&)
    Weave::OidcClient.clear_cache!
    stub_request(:get, "#{ISSUER}/.well-known/openid-configuration").to_return(
      status: 200, headers: { "Content-Type" => "application/json" },
      body: {
        issuer: ISSUER,
        authorization_endpoint: "#{ISSUER}/oauth/authorize",
        token_endpoint: "#{ISSUER}/oauth/token",
        jwks_uri: "#{ISSUER}/oauth/discovery/keys"
      }.to_json
    )
    stub_request(:get, "#{ISSUER}/oauth/discovery/keys").to_return(
      status: 200, headers: { "Content-Type" => "application/json" }, body: { keys: [ JWK.export ] }.to_json
    )
    with_env(fake_weave_env, &)
  ensure
    Weave::OidcClient.clear_cache!
  end

  def id_token_for(nonce:, sub: "PWL5A1B2C3D4", roles: %w[viewer], key: KEY, kid: JWK.kid, **overrides)
    now = Time.current.to_i
    claims = {
      iss: ISSUER, aud: CLIENT_ID, sub: sub, iat: now, exp: now + 300, nonce: nonce,
      name: "Weave User", email: "user@example.org", roles: roles
    }.merge(overrides).compact
    JWT.encode(claims, key, "RS256", { kid: kid })
  end

  # Weave's token endpoint answers the code with this id_token.
  def stub_token_endpoint(id_token: nil, status: 200)
    stub_request(:post, "#{ISSUER}/oauth/token").to_return(
      status: status, headers: { "Content-Type" => "application/json" },
      body: (id_token ? { access_token: "at", token_type: "Bearer", id_token: id_token } : {}).to_json
    )
  end

  INTROSPECT_URL = "#{ISSUER}/oauth/introspect".freeze
  PATCH_APP_CLIENT_ID = "krater-test-client".freeze

  # Weave's introspection endpoint answers for this token. Only a request with Stash's own
  # client credentials (HTTP Basic) and this token in the form matches.
  def stub_introspection(token:, active: true, client_id: PATCH_APP_CLIENT_ID, scope: "stash", exp: 1.hour.from_now.to_i,
    status: 200, body: nil)
    answer = active ? { active: true, client_id: client_id, scope: scope, exp: exp, token_type: "Bearer" } : { active: false }
    stub_request(:post, INTROSPECT_URL)
      .with(basic_auth: [ CLIENT_ID, "test-secret" ], body: hash_including("token" => token))
      .to_return(status: status, headers: { "Content-Type" => "application/json" },
        body: body || answer.compact.to_json)
  end

  TOKEN_URL = "#{ISSUER}/oauth/token".freeze
  DIRECTORY_URL = "#{ISSUER}/api/v1/directory/users/".freeze
  DIRECTORY_TOKEN = "stash-directory-token".freeze

  # Weave's token endpoint gives Stash a client_credentials token for the scope. Only a request
  # with Stash's own client credentials (HTTP Basic) matches.
  def stub_client_credentials(scope: "directory", token: DIRECTORY_TOKEN, expires_in: 7200, status: 200)
    stub_request(:post, TOKEN_URL)
      .with(basic_auth: [ CLIENT_ID, "test-secret" ], body: hash_including("grant_type" => "client_credentials", "scope" => scope))
      .to_return(status: status, headers: { "Content-Type" => "application/json" },
        body: status == 200 ? { access_token: token, token_type: "Bearer", expires_in: expires_in, scope: scope }.to_json : "{}")
  end

  # Weave's directory answers for the sub, as DirectoryUserSerializer shows it to Stash's app.
  def stub_directory_user(sub, roles: %w[finance], active: true, name: "Weave User", status: 200, body: nil,
    token: DIRECTORY_TOKEN)
    answer = { sub: sub, name: name, email: "#{sub.downcase}@example.org", email_verified: true, slack_id: nil,
               slack_member: false, groups: [], roles: roles, active: active }
    stub_request(:get, "#{DIRECTORY_URL}#{sub}").with(headers: { "Authorization" => "Bearer #{token}" })
      .to_return(status: status, headers: { "Content-Type" => "application/json" },
        body: body || (status == 200 ? answer.to_json : { error: "not_found" }.to_json))
  end

  # Weave's env, a fresh token cache, a token and the person's directory record, for the block.
  def with_weave_directory(sub, roles: %w[finance], active: true, name: "Weave User", status: 200, &)
    Weave::ClientCredentials.clear_cache!
    stub_client_credentials
    stub_directory_user(sub, roles: roles, active: active, name: name, status: status)
    with_env(fake_weave_env, &)
  ensure
    Weave::ClientCredentials.clear_cache!
  end

  # Swaps Rails.cache (a null store in tests) for a memory store during the block.
  def with_memory_cache
    old = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    yield Rails.cache
  ensure
    Rails.cache = old
  end
end
