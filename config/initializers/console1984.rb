# frozen_string_literal: true

Console1984.config do |config|
  # Require a reason for console access
  config.ask_for_session_reason = true

  # Protected URLs that will be flagged when accessed
  config.protected_urls = [
    %r{/admin},
    %r{/users/\d+}
  ]

  # Protected environments (production by default)
  config.protected_environments = %i[production]

  # Incinerate console sessions after this period
  config.incinerate_after = 30.days

  # Enable/disable encryption of console commands
  config.encrypt_session_data = true
end
