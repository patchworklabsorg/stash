# frozen_string_literal: true

# Lockbox - Field-level encryption
# https://github.com/ankane/lockbox
#
# Generate key with: Lockbox.generate_key

if Rails.application.credentials.lockbox&.key?(:master_key)
  Lockbox.master_key = Rails.application.credentials.lockbox[:master_key]
elsif ENV['LOCKBOX_MASTER_KEY'].present?
  Lockbox.master_key = ENV['LOCKBOX_MASTER_KEY']
elsif Rails.env.production?
  raise 'Lockbox master_key not configured! Run: rails credentials:edit'
else
  Rails.logger.warn 'Lockbox master_key not found in credentials. Add it with: rails credentials:edit'
end
