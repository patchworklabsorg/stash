# frozen_string_literal: true

require Rails.root.join('app/middleware/request_metrics')

Rails.application.config.middleware.use RequestMetrics
