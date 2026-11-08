# frozen_string_literal: true

# Logstop filters sensitive data from logs.
# By default it filters: email, phone, credit card, SSN, IP addresses.
# Stash also scrubs bearer tokens, in case one ever reaches a log line. Stash never logs them on purpose.
if defined?(Logstop)
  Logstop.guard(Rails.logger, scrubber: lambda { |message|
    message.gsub(/(Bearer\s+)[^\s"',]+/i, "\\1[FILTERED]")
  })
end
