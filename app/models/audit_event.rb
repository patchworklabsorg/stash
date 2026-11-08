# A person's admin action, with a required reason. Append-only: never update or delete a row.
# The subject is named by its public id, so the event survives the subject's deletion.
class AuditEvent < CentralRecord
  ACTIONS = %w[archive.deleted archive.rerun].freeze

  validates :actor_sub, :action, :subject_type, :subject_public_id, :reason, presence: true
  validates :action, inclusion: { in: ACTIONS }

  scope :recent, -> { order(created_at: :desc) }

  def readonly?
    persisted?
  end
end
