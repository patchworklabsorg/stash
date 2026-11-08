# frozen_string_literal: true

Rails.application.configure do
  # Tests use Active Job's test adapter, so they can assert on enqueued jobs.
  config.active_job.queue_adapter = Rails.env.test? ? :test : :good_job

  config.good_job = {
    # GoodJob uses the same database and schema as the rest of Stash.
    active_record_parent_class: "CentralRecord",
    # Run jobs inside the web process in development; use a separate worker in production and staging.
    execution_mode: Rails.env.local? ? :async : :external,
    # Captures run Chromium, git, yt-dlp and LibreOffice. Two at a time is plenty for one host.
    max_threads: ENV.fetch("GOOD_JOB_MAX_THREADS", 2).to_i,
    poll_interval: ENV.fetch("GOOD_JOB_POLL_INTERVAL", 5).to_i,
    queues: ENV.fetch("GOOD_JOB_QUEUES", "*"),
    enable_cron: false,
    preserve_job_records: true,
    cleanup_preserved_jobs_before_seconds_ago: 14.days.to_i
  }
end
