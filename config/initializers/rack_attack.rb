# frozen_string_literal: true

# Rate limits. The API is throttled per token (a hash of it), the sign-in routes per address.
class Rack::Attack
  Rack::Attack.cache.store = Rails.cache

  throttle("api/token", limit: 120, period: 1.minute) do |req|
    if req.path.start_with?("/api/")
      token = req.get_header("HTTP_AUTHORIZATION").to_s
      token.present? ? Digest::SHA256.hexdigest(token) : req.ip
    end
  end

  throttle("sign_in/ip", limit: 20, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/auth/", "/sign_in", "/dev/sign_in")
  end

  self.throttled_responder = lambda do |request|
    period = request.env["rack.attack.match_data"][:period]
    [ 429, { "Content-Type" => "application/json", "Retry-After" => period.to_s }, [ { error: "rate_limited" }.to_json ] ]
  end
end

Rails.application.config.middleware.use Rack::Attack unless Rails.env.test?
