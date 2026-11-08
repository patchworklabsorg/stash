# frozen_string_literal: true

return unless defined?(StatsD)

# Configure StatsD client
# In production, point to your StatsD server (e.g., Datadog agent)
# In development, logs to Rails logger
StatsD.singleton_client = StatsD::Instrument::Client.new(
  sink: if Rails.env.production?
          StatsD::Instrument::UDPSink.new(
            ENV.fetch('STATSD_HOST', 'localhost'),
            ENV.fetch('STATSD_PORT', 8125).to_i
          )
        else
          StatsD::Instrument::LogSink.new(Rails.logger)
        end,
  prefix: Rails.application.class.module_parent_name.underscore,
  default_tags: [
    "env:#{Rails.env}",
    "app:#{Rails.application.class.module_parent_name.underscore}"
  ]
)
