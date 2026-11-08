# frozen_string_literal: true

Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.formatter = Rails.env.local? ? Lograge::Formatters::KeyValue.new : Lograge::Formatters::Json.new
  config.lograge.custom_payload do |controller|
    { request_id: controller.request.request_id }
  end
  config.lograge.keep_original_rails_log = Rails.env.development?
end
