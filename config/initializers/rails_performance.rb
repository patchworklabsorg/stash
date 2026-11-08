# frozen_string_literal: true

RailsPerformance.setup do |config|
  # Storage backend (Redis required)
  config.redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))

  # Data retention
  config.duration = 4.hours

  # Enable/disable features
  config.enabled = true

  # Skip certain paths from tracking
  config.skipable_rake_tasks = %w[assets:precompile]

  # Ignore certain request paths
  config.ignored_paths = [
    '/health',
    '/assets'
  ]

  # Custom event tracking
  # config.custom_data_proc = proc { |env|
  #   {
  #     user_id: env['warden']&.user&.id
  #   }
  # }
end if defined?(RailsPerformance)
