# frozen_string_literal: true

# Warm caches for frequently accessed data
#
# Schedule this job to run periodically:
#   CacheWarmerJob.perform_later
#
# Or warm specific caches:
#   CacheWarmerJob.perform_later(caches: ['users', 'settings'])
#
class CacheWarmerJob < ApplicationJob
  queue_as :low

  def perform(caches: nil)
    warmers = caches || default_warmers
    warmers.each { |warmer| send("warm_#{warmer}") }
  end

  private

  def default_warmers
    %w[settings]
  end

  # Add your cache warming methods here
  #
  # def warm_users
  #   User.active.find_each do |user|
  #     Rails.cache.fetch(user.cache_key_with_version) { user }
  #   end
  # end

  def warm_settings
    # Example: warm application settings
    # AppConfig.all.each do |config|
    #   Rails.cache.fetch(['app_config', config.key]) { config.value }
    # end
  end
end
