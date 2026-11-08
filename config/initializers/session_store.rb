# frozen_string_literal: true

# Use Redis for session storage
Rails.application.config.session_store :redis_session_store,
  key: "_#{Rails.application.class.module_parent_name.underscore}_session",
  redis: {
    expire_after: 90.minutes,
    key_prefix: 'session:',
    url: ENV.fetch('REDIS_URL') { 'redis://localhost:6379/2' }
  }
