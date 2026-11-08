# frozen_string_literal: true

# Example recurring job for cleanup tasks
# Configure schedule in config/initializers/good_job.rb
#
# cron: {
#   cleanup: {
#     cron: '0 4 * * *',  # 4am daily
#     class: 'CleanupJob'
#   }
# }
#
class CleanupJob < ApplicationJob
  queue_as :low

  def perform
    cleanup_expired_sessions
    cleanup_old_versions
    cleanup_orphaned_records
  end

  private

  def cleanup_expired_sessions
    # Remove sessions older than 30 days
    Session.where('created_at < ?', 30.days.ago).delete_all
  end

  def cleanup_old_versions
    # Remove PaperTrail versions older than 90 days (if using paper_trail)
    return unless defined?(PaperTrail)

    PaperTrail::Version.where('created_at < ?', 90.days.ago).delete_all
  end

  def cleanup_orphaned_records
    # Add your cleanup logic here
  end
end
