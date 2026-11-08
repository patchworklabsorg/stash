# frozen_string_literal: true

# Include in ApplicationController for visit/event tracking
#
# Usage in controllers:
#   ahoy.track "Viewed Product", product_id: product.id
#
# Usage in views:
#   <% ahoy.track "Viewed Page", page: request.path %>
#
module Trackable
  extend ActiveSupport::Concern

  included do
    # Track visits automatically
    # before_action :track_ahoy_visit
  end

  def track_event(name, properties = {})
    ahoy.track(name, properties)
  end
end
