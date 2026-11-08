# frozen_string_literal: true

# Public ids: a type prefix and a base62 encoding of the UUID, for example arc_4k8xJm2pN9qW.
# The prefixes are registered in internal-docs (encoded-id-prefixes.md). They are in every URL.
EncodedIds.configure do |config|
  config.separator = "_"
  config.use_prefix_in_routes = true
end
