# frozen_string_literal: true

# PgHero - PostgreSQL insights
# Dashboard: /admin/pghero

ENV['PGHERO_USERNAME'] ||= Rails.application.credentials.dig(:pghero, :username) || 'admin'
ENV['PGHERO_PASSWORD'] ||= Rails.application.credentials.dig(:pghero, :password) || 'admin'
