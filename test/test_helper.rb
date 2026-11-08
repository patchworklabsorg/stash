ENV["RAILS_ENV"] ||= "test"
# Tests sign in through the dev sign-in. The routes for it exist only in dev mode.
ENV["STASH_AUTH_MODE"] = "dev"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Sets environment variables for the block, then restores them.
    def with_env(values)
      old = values.keys.to_h { |key| [ key, ENV[key] ] }
      values.each { |key, value| ENV[key] = value }
      yield
    ensure
      old.each { |key, value| ENV[key] = value }
    end

    # Replaces a module or class method for the block. `value` is returned, or called when it is a proc.
    def stub_method(target, name, value)
      original = target.method(name)
      target.define_singleton_method(name) { |*args| value.respond_to?(:call) ? value.call(*args) : value }
      yield
    ensure
      target.define_singleton_method(name, original)
    end

    def create_archive(url: "https://example.org/project", **attributes)
      Archive.create!(url: url, **attributes)
    end

    # An archive with one capture per method, each in the given status.
    def create_archive_with_captures(statuses, url: "https://example.org/project")
      archive = create_archive(url: url)
      statuses.each_with_index do |(method_name, status), position|
        archive.captures.create!(method_name: method_name, status: status, position: position)
      end
      archive.refresh_status!
      archive
    end

    def admin_user
      SessionUser.new(sub: "PWLADMIN0001", name: "Ada", email: "", roles: %w[admin], signed_in_at: Time.current)
    end

    def viewer_user
      SessionUser.new(sub: "PWLVIEWER001", name: "Vic", email: "", roles: %w[viewer], signed_in_at: Time.current)
    end

    def archivist_user
      SessionUser.new(sub: "PWLARCHIV001", name: "Archie", email: "", roles: %w[archivist], signed_in_at: Time.current)
    end
  end
end

module ActionDispatch
  class IntegrationTest
    def sign_in_as(*roles, sub: "PWLTEST00001", name: "Test User")
      post dev_sign_in_path, params: { sub: sub, name: name, roles: roles.map(&:to_s) }
    end
  end
end
