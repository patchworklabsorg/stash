# frozen_string_literal: true

module FeatureHelper
  # Check if a feature is enabled for the current user
  #
  # Usage in views:
  #   <% if feature_enabled?(:new_dashboard) %>
  #     <%= render 'new_dashboard' %>
  #   <% end %>
  #
  def feature_enabled?(feature, actor = current_user)
    Flipper.enabled?(feature, actor)
  end
end
