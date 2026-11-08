module Stash
  # Picks how people sign in, from STASH_AUTH_MODE.
  #
  #   weave  OIDC sign-in with Weave. The default, and the only mode allowed in production
  #          and staging.
  #   dev    A local page that signs you in as a fake user with the roles you pick.
  #          For development and tests only.
  module AuthMode
    MODES = %w[weave dev].freeze
    DEFAULT = "weave"

    class Error < StandardError; end

    def self.current
      mode = ENV["STASH_AUTH_MODE"].presence || DEFAULT
      MODES.include?(mode) ? mode : DEFAULT
    end

    def self.dev?
      current == "dev"
    end

    # Called once at boot. Raises so that the app does not start with an unsafe setting.
    def self.verify!(env:, mode:)
      mode = mode.presence || DEFAULT
      unless MODES.include?(mode)
        raise Error, "STASH_AUTH_MODE must be one of #{MODES.join(", ")}, not #{mode.inspect}"
      end
      if mode == "dev" && Stash::Deployment.deployed?(env)
        raise Error, "STASH_AUTH_MODE=dev is not allowed in #{env}"
      end

      mode
    end
  end
end
