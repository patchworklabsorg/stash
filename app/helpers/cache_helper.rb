# frozen_string_literal: true

# Helper methods for view caching
#
# Russian Doll Caching:
#   The key insight is that when a nested object changes,
#   only its cache (and parent caches) are invalidated.
#
# Example view structure:
#   <% cache @project do %>
#     <%= render @project.tasks %>
#   <% end %>
#
#   # _task.html.erb
#   <% cache task do %>
#     <%= task.name %>
#     <%= render task.comments %>
#   <% end %>
#
module CacheHelper
  # Cache with automatic expiry based on record updated_at
  # Also includes a version number for manual cache busting
  #
  # Usage:
  #   <% cache_with_version @user, 'v2' do %>
  #     ...
  #   <% end %>
  #
  def cache_with_version(record, version = 'v1', options = {}, &block)
    cache([version, record], options, &block)
  end

  # Cache a collection with automatic key generation
  # Useful for lists that change frequently
  #
  # Usage:
  #   <% cache_collection @users do |user| %>
  #     <%= render user %>
  #   <% end %>
  #
  def cache_collection(collection, options = {}, &block)
    cache([collection.cache_key_with_version, collection.size], options, &block)
  end

  # Time-based cache for content that should refresh periodically
  #
  # Usage:
  #   <% cache_for 5.minutes, 'dashboard_stats' do %>
  #     ...
  #   <% end %>
  #
  def cache_for(duration, key, options = {}, &block)
    expires_key = (Time.current.to_i / duration.to_i)
    cache([key, expires_key], options, &block)
  end
end
