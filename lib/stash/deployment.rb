module Stash
  # Which Rails environments are deployed, and so get the production safety checks.
  #
  #   development, test  local only. Dev sign-in and the Mercury sandbox default are allowed.
  #   staging            deployed, with the Mercury sandbox only. It refuses the live Mercury URL,
  #                      so it can never move real money. Every other production check applies.
  #   production         deployed, with the live Mercury API only. It refuses the sandbox URL.
  #
  # Any other environment name counts as deployed and gets the production rules.
  module Deployment
    LOCAL_ENVS = %w[development test].freeze

    def self.deployed?(env)
      !LOCAL_ENVS.include?(env.to_s)
    end

    def self.staging?(env)
      env.to_s == "staging"
    end
  end
end
