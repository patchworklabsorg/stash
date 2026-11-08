# frozen_string_literal: true

# Blind Index - Searchable Encryption
# https://github.com/ankane/blind_index
#
# Allows searching encrypted columns without decrypting them
# Generate key with: BlindIndex.generate_key

if Rails.application.credentials.blind_index&.key?(:master_key)
  BlindIndex.master_key = Rails.application.credentials.blind_index[:master_key]
elsif ENV['BLIND_INDEX_MASTER_KEY'].present?
  BlindIndex.master_key = ENV['BLIND_INDEX_MASTER_KEY']
elsif Rails.env.production?
  raise 'BlindIndex master_key not configured! Run: rails credentials:edit'
else
  Rails.logger.warn 'BlindIndex master_key not found in credentials. Add it with: rails credentials:edit'
end

# Default options
BlindIndex.default_options[:algorithm] = :argon2id  # Most secure, recommended
BlindIndex.default_options[:insecure_key] = false   # Require secure keys
