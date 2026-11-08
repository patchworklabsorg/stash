# frozen_string_literal: true

return unless defined?(Lograge)

Rails.application.configure do
  # Enable lograge for structured logging
  config.lograge.enabled = true

  # Use JSON format in production for log aggregation
  config.lograge.formatter = if Rails.env.production?
                                Lograge::Formatters::Json.new
                              else
                                Lograge::Formatters::KeyValue.new
                              end

  # Include request_id for tracing across services
  config.lograge.custom_options = lambda do |event|
    {
      request_id: event.payload[:request_id],
      user_id: event.payload[:user_id],
      ip: event.payload[:ip],
      host: event.payload[:host]
    }.compact
  end

  # Add custom data to the payload
  config.lograge.custom_payload do |controller|
    {
      request_id: controller.request.request_id,
      user_id: controller.try(:current_user)&.id,
      ip: controller.request.remote_ip,
      host: controller.request.host
    }
  end

  # Keep original Rails logs in development
  config.lograge.keep_original_rails_log = Rails.env.development?
end
