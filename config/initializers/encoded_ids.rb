# frozen_string_literal: true

# Public ids: a type prefix and a base62 encoding of the UUID, for example arc_4k8xJm2pN9qW.
# The prefixes are registered in internal-docs (encoded-id-prefixes.md). Per the org rule
# (public-ids.md), routes hold the id without the prefix; the UI, the API and the logs show the
# full id. CentralRecord.find_by_public_param! accepts both forms.
EncodedIds.configure do |config|
  config.separator = "_"
  config.use_prefix_in_routes = false
end
