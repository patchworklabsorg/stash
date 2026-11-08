# One request to archive one URL. The unit that a patch app references and that a reviewer opens.
#
# Statuses:
#   queued   ArchiveJob has not run yet, or no capture has started
#   running  at least one capture is running, and none has finished
#   done     every capture that applies is done
#   partial  at least one capture is done and at least one failed
#   failed   no capture is done
#
# The status is derived from the captures (see #refresh_status!). Nobody sets it by hand.
#
# Stash stores the requester's Weave sub only, never a name or email (member data rule).
class Archive < CentralRecord
  # A short public id, for example arc_4k8xJm2pN9qW. The prefix "arc" is registered in
  # internal-docs (encoded-id-prefixes.md).
  include EncodedIds::UuidIdentifiable
  set_public_id_prefix "arc"

  STATUSES = %w[queued running done partial failed].freeze
  KINDS = Capturers::Router::KINDS

  has_many :captures, -> { order(:position) }, dependent: :destroy, inverse_of: :archive
  has_many :artifacts, through: :captures

  validates :url, presence: true, length: { maximum: 2048 }
  validates :normalized_url, :host, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :note, length: { maximum: 2000 }
  validate :url_is_http

  before_validation :normalize

  scope :recent, -> { order(created_at: :desc) }
  scope :for_url, ->(url) { where(normalized_url: UrlNormalizer.call(url)) }
  # Archives whose URL, host or note has the term. A blank term matches all.
  scope :matching, lambda { |term|
    term = term.to_s.strip.first(200)
    next all if term.empty?

    pattern = "%#{sanitize_sql_like(term)}%"
    where("archives.url ILIKE :p OR archives.host ILIKE :p OR archives.note ILIKE :p", p: pattern)
  }

  # The submission a patch app references, when it gives one. With a client_id, it makes POST
  # /api/v1/archives idempotent (see Api::V1::ArchivesController).
  def self.submission_ref_from(reference)
    value = reference.is_a?(Hash) ? reference["submission"] : nil
    value.is_a?(String) && value.present? ? value.first(200) : nil
  end

  # Sets the status from the captures. Call it after a capture changes.
  def refresh_status!
    states = captures.where.not(status: "skipped").pluck(:status)
    self.status =
      if states.empty? || states.all?("queued") then "queued"
      elsif states.all?("done") then "done"
      elsif states.none?("done") && states.all? { |s| %w[failed].include?(s) } then "failed"
      elsif states.any?("running") || states.any?("queued") then "running"
      elsif states.any?("done") then "partial"
      else "failed"
      end
    self.completed_at = %w[done partial failed].include?(status) ? Time.current : nil
    save!
  end

  def finished?
    %w[done partial failed].include?(status)
  end

  def title
    "#{host} · #{kind}"
  end

  private

  def normalize
    self.url = url.to_s.strip
    self.normalized_url = UrlNormalizer.call(url) if url.present?
    self.host = UrlNormalizer.host(url) if url.present?
    self.kind ||= Capturers::Router.kind_for(url) if url.present?
    self.submission_ref = self.class.submission_ref_from(reference)
    self.reference = {} unless reference.is_a?(Hash)
  end

  def url_is_http
    uri = URI.parse(url.to_s)
    errors.add(:url, "must be an http or https URL") unless uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    errors.add(:url, "is not a valid URL")
  end
end
