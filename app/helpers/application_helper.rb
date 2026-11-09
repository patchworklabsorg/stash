module ApplicationHelper
  # True on the staging deployment. That is RAILS_ENV=staging, or STASH_ENVIRONMENT=staging for
  # a deployment that runs with another Rails environment. Production never matches.
  def staging_environment?
    Rails.env.staging? || ENV["STASH_ENVIRONMENT"] == "staging"
  end

  # The badge tone of each status word (internal-docs design/tokens.md: state uses the semantic
  # tones). The badge always shows the word too, so the color never carries the meaning alone.
  STATUS_TONES = {
    "done" => :success,
    "running" => :info,
    "queued" => :neutral,
    "partial" => :warning,
    "skipped" => :outline,
    "failed" => :danger
  }.freeze

  def status_badge(status)
    return "" if status.blank?

    badge status.to_s, tone: STATUS_TONES.fetch(status.to_s, :neutral)
  end
end
