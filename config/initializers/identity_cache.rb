# frozen_string_literal: true

# IdentityCache - Blob level caching for Active Record
# See: https://github.com/Shopify/identity_cache

IdentityCache.logger = Rails.logger
IdentityCache.cache_backend = Rails.cache
