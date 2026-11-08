# frozen_string_literal: true

MetaTags.configure do |config|
  # How many characters to truncate title to
  config.title_limit = 70

  # How many characters to truncate description to
  config.description_limit = 160

  # Truncate site_title if title is too long
  config.truncate_site_title_first = false
end
