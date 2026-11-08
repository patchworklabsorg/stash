# frozen_string_literal: true

EncodedIds.configure do |config|
  # Salt from credentials (generate with: SecureRandom.hex(32))
  # rails credentials:edit → add: hashid: { salt: "..." }
  config.hashid_salt = Rails.application.credentials.dig(:hashid, :salt) || ENV["HASHID_SALT"]

  # Minimum length of the hash portion (before prefix)
  config.hashid_min_length = 8

  # Character set for hash generation (lowercase + numbers)
  config.hashid_alphabet = "abcdefghijklmnopqrstuvwxyz0123456789"

  # Separator between prefix and hash (e.g. usr_abc123)
  config.separator = "_"

  # false = /users/abc123 (cleaner), true = /users/usr_abc123 (Stripe style)
  config.use_prefix_in_routes = false
end
