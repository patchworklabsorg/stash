# One method run against an archive's URL. Capturers::Router picks the methods; CaptureJob runs them.
#
# Statuses:
#   queued   waiting for a worker
#   running  the capturer is running
#   done     the capturer stored its artifacts
#   failed   the capturer raised, timed out or passed the size limit; `error` says which
#   skipped  the method does not apply after all (for example, HEAD said the URL is HTML, so no file)
#
# A capture is never deleted when it fails, so the archive shows what was tried.
class Capture < CentralRecord
  # The prefix "cap" is registered in internal-docs (encoded-id-prefixes.md).
  include EncodedIds::UuidIdentifiable
  set_public_id_prefix "cap"

  STATUSES = %w[queued running done failed skipped].freeze
  METHODS = Capturers::Router::METHODS

  belongs_to :archive, inverse_of: :captures
  has_many :artifacts, dependent: :destroy, inverse_of: :capture

  validates :method_name, inclusion: { in: METHODS }, uniqueness: { scope: :archive_id }
  validates :status, inclusion: { in: STATUSES }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :unfinished, -> { where(status: %w[queued running]) }

  def capturer
    Capturers::Router.capturer_for(method_name)
  end

  def finished?
    %w[done failed skipped].include?(status)
  end

  def duration
    return nil unless started_at && finished_at

    finished_at - started_at
  end

  # Appends a line to the log. The log is capped so a noisy tool cannot fill the table.
  def log!(line)
    self.log = "#{log}#{line.to_s.chomp}\n".last(64.kilobytes)
  end
end
