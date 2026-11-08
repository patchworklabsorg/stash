# frozen_string_literal: true

# Include in models for identity caching
#
# Usage:
#   class User < ApplicationRecord
#     include Cacheable
#
#     cache_index :email
#     cache_has_many :posts
#   end
#
#   User.fetch(1)              # Cached fetch by id
#   User.fetch_by_email(email) # Cached fetch by index
#
module Cacheable
  extend ActiveSupport::Concern

  included do
    include IdentityCache
  end

  class_methods do
    # Expire cache when record is updated
    def expire_cache_for(record)
      record.expire_cache if record.respond_to?(:expire_cache)
    end
  end
end
