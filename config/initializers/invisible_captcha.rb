# frozen_string_literal: true

InvisibleCaptcha.setup do |config|
  # Minimum time (in seconds) for a human to fill out a form
  config.timestamp_threshold = 2

  # Custom honeypot field name (randomized per form by default)
  # config.honeypots = ['foo', 'bar']

  # Flash message when spam is detected
  config.timestamp_error_message = 'Something went wrong. Please try again.'

  # Enable visual mode for debugging in development
  config.visual_honeypots = Rails.env.development?
end
