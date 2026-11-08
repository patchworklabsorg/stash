# Everything that talks to Weave, the Patchwork identity provider, lives in this namespace.
module Weave
  class Error < StandardError; end
  # Sign-in failed because of what Weave or the browser sent (a bad code, a bad id_token).
  class AuthError < Error; end
  # Weave did not answer, or answered with an error.
  class UnavailableError < Error; end
  # A WEAVE_* variable is missing.
  class ConfigurationError < Error; end
end
