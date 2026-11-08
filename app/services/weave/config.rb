module Weave
  # Weave settings, read from the environment each time, so tests can change them.
  class Config
    VARIABLES = %w[WEAVE_ISSUER WEAVE_CLIENT_ID WEAVE_CLIENT_SECRET].freeze

    def self.configured?
      VARIABLES.all? { |name| ENV[name].present? }
    end

    def self.issuer
      fetch("WEAVE_ISSUER").chomp("/")
    end

    def self.client_id
      fetch("WEAVE_CLIENT_ID")
    end

    def self.client_secret
      fetch("WEAVE_CLIENT_SECRET")
    end

    def self.fetch(name)
      ENV[name].presence || raise(ConfigurationError, "#{name} is not set")
    end
    private_class_method :fetch
  end
end
