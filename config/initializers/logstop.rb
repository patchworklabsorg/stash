# frozen_string_literal: true

# Logstop filters sensitive data from logs
# By default it filters: email, phone, credit card, SSN, IP addresses

if defined?(Logstop)
  Logstop.guard(Rails.logger)

  # Add custom scrubbers for application-specific sensitive data
  # Logstop.scrub(pattern, replacement)
  #
  # Example: Scrub API keys
  # Logstop.scrub(/api_key=\w+/, 'api_key=[FILTERED]')
end
