# frozen_string_literal: true

# Include in models that can be used as Flipper actors
#
# Usage:
#   class User < ApplicationRecord
#     include Featureable
#   end
#
#   Flipper.enable(:new_dashboard, user)
#   Flipper.enabled?(:new_dashboard, user)
#
module Featureable
  extend ActiveSupport::Concern

  # Uses public_id if available (e.g., "user_abc123"), otherwise falls back to "ClassName;id"
  def flipper_id
    respond_to?(:public_id) ? public_id : "#{self.class.name};#{id}"
  end
end
