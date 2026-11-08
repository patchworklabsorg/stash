require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
# require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
# require "action_cable/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

require_relative "../lib/stash/deployment"
require_relative "../lib/stash/auth_mode"

module Stash
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Timestamps are UTC everywhere.
    config.time_zone = "UTC"
    config.active_record.default_timezone = :utc

    # Primary keys are UUIDs.
    config.generators do |g|
      g.orm :active_record, primary_key_type: :uuid
      g.system_tests = nil
    end

    # A signed-in session is good for this long. The cookie and the Authentication concern both check it.
    config.x.session_lifetime = 8.hours

    # Refuse to boot with an unsafe sign-in mode in a deployed environment.
    config.x.auth_mode = Stash::AuthMode.verify!(env: Rails.env, mode: ENV["STASH_AUTH_MODE"])
  end
end
