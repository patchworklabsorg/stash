source "https://rubygems.org"

gem "rails", "~> 8.1.4", ">= 8.1.4.1"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Bundle and transpile JavaScript [https://github.com/rails/jsbundling-rails]
gem "jsbundling-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
gem "tailwindcss-rails"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Postgres-backed Active Job adapter with cron [https://github.com/bensheldon/good_job]
gem "good_job"

# Verify Weave id_tokens against Weave's JWKS [https://github.com/jwt/ruby-jwt]
gem "jwt"

# Authorization policies, one per model, in app/policies [https://github.com/varvet/pundit]
gem "pundit"

# Short public ids with a type prefix, for example arc_4k8xJm2pN9qW. Prefixes are listed in internal-docs.
gem "encoded_ids", "~> 1.1"

# Artifacts live in Active Storage, on disk locally and in an S3-compatible bucket when deployed.
gem "aws-sdk-s3", require: false

# Headless Chrome for page snapshots, screenshots and print PDFs [https://github.com/rubycdp/ferrum]
gem "ferrum"

# ZIP archives for gallery captures [https://github.com/rubyzip/rubyzip]
gem "rubyzip", require: "zip"

# Pagination for the list pages
gem "kaminari"

# Rate limits on the API and the sign-in routes
gem "rack-attack"

# Logging: one line per request, and scrub sensitive values
gem "lograge"
gem "logstop"

# Catch unsafe migrations before they run [https://github.com/ankane/strong_migrations]
gem "strong_migrations"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # Load .env files in development and test
  gem "dotenv-rails"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # HTML+ERB linter and formatter
  gem "herb"
end

group :test do
  # Stub Weave's HTTP endpoints in tests
  gem "webmock"
end

# Lucide, the Patchwork icon set (internal-docs design/icons.md).
gem "lucide-rails", "~> 0.7.4"
