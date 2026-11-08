# frozen_string_literal: true

# Configure Rack Attack for rate limiting
class Rack::Attack
  # Use Rails.cache (backed by Redis in production)
  Rack::Attack.cache.store = Rails.cache

  # Throttle all requests by IP (300 req/5 minutes)
  throttle('req/ip', limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?('/assets')
  end

  # Throttle login attempts by email
  throttle('logins/email', limit: 5, period: 20.seconds) do |req|
    if req.path == '/sign_in' && req.post?
      req.params['email']&.to_s&.downcase&.gsub(/\s+/, '')
    end
  end

  # Throttle password reset attempts
  throttle('password_resets/email', limit: 3, period: 20.minutes) do |req|
    if req.path == '/password/reset' && req.post?
      req.params['email']&.to_s&.downcase&.gsub(/\s+/, '')
    end
  end

  # Block suspicious requests
  blocklist('block suspicious requests') do |req|
    # Block requests with suspicious patterns
    Rack::Attack::Fail2Ban.filter("pentesters-#{req.ip}", maxretry: 5, findtime: 10.minutes, bantime: 1.hour) do
      # Return true if this is a suspicious request
      CGI.unescape(req.query_string) =~ %r{/etc/passwd} ||
      req.path.include?('/etc/passwd') ||
      req.path.include?('wp-admin') ||
      req.path.include?('wp-login')
    end
  end

  # Always allow requests from localhost in development
  safelist('allow from localhost') do |req|
    req.ip == '127.0.0.1' || req.ip == '::1' if Rails.env.development?
  end

  # Custom response for throttled requests
  self.throttled_responder = lambda do |request|
    match_data = request.env['rack.attack.match_data']
    now = Time.now.utc

    headers = {
      'Content-Type' => 'application/json',
      'Retry-After' => (match_data[:period] - (now.to_i % match_data[:period])).to_s
    }

    [429, headers, [{ error: 'Rate limit exceeded. Please try again later.' }.to_json]]
  end
end
