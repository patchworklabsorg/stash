# frozen_string_literal: true

require 'flipper'
require 'flipper/adapters/active_record'
require 'flipper/adapters/active_support_cache_store'

Flipper.configure do |config|
  config.default do
    adapter = Flipper::Adapters::ActiveRecord.new
    cached_adapter = Flipper::Adapters::ActiveSupportCacheStore.new(
      adapter,
      Rails.cache,
      expires_in: 5.minutes
    )
    Flipper.new(cached_adapter)
  end
end

# Register groups
Flipper.register(:staff) do |actor, _context|
  actor.respond_to?(:admin_or_above?) && actor.admin_or_above?
end

Flipper.register(:admins) do |actor, _context|
  actor.respond_to?(:admin?) && actor.admin?
end

Flipper.register(:super_admins) do |actor, _context|
  actor.respond_to?(:super_admin?) && actor.super_admin?
end

# Configure Flipper UI
Flipper::UI.configure do |config|
  config.application_breadcrumb_href = '/'
  config.feature_creation_enabled = true
  config.feature_removal_enabled = true

  if Rails.env.production?
    config.banner_text = 'Production Environment'
    config.banner_class = 'danger'
  elsif Rails.env.staging?
    config.banner_text = 'Staging Environment'
    config.banner_class = 'warning'
  end
end
