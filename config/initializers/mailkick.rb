# frozen_string_literal: true

# Mailkick - Email unsubscribe management
# https://github.com/ankane/mailkick

Mailkick.secret_token = Rails.application.credentials.dig(:mailkick, :secret_token) ||
                        Rails.application.secret_key_base

# Optional: Use a custom method to check opt-outs
# Mailkick.user_method = ->(email) { User.find_by(email: email) }
