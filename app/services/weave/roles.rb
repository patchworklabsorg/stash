module Weave
  # Maps the `roles` claim from Weave to Stash's app roles.
  # This is the only place that knows the role keys.
  #
  #   viewer     opens archives and downloads artifacts
  #   archivist  also archives a URL by hand, and runs an archive again
  #   admin      also deletes an archive, with a reason
  module Roles
    ALL = %w[viewer archivist admin].freeze

    # A value that is not a list counts as no roles, so a malformed claim fails closed.
    # Unknown keys are ignored.
    def self.from_claim(value)
      return [] unless value.is_a?(Array)

      ALL & value.grep(String)
    end
  end
end
