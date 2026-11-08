# frozen_string_literal: true

# Configure ahoy_email for email tracking
AhoyEmail.api = true

# Default tracking options
AhoyEmail.default_options[:message] = true      # Store message metadata
AhoyEmail.default_options[:open] = true         # Track email opens (via tracking pixel)
AhoyEmail.default_options[:click] = true        # Track link clicks
AhoyEmail.default_options[:utm_params] = false  # Don't add UTM parameters

# Register the message subscriber to store messages
AhoyEmail.subscribers << AhoyEmail::MessageSubscriber

# Configure message model
AhoyEmail.message_model = -> { Ahoy::Message }

# Track email opens and clicks
# Note: Opens require an image to be loaded, which may be blocked by email clients
# Clicks work by redirecting through the application before going to the final URL
