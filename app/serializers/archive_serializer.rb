# The JSON shape of an archive in the API and on the page. Public ids only; no database ids,
# no requester sub (the requester is the caller's concern, not another app's).
class ArchiveSerializer
  include Rails.application.routes.url_helpers

  def initialize(archive)
    @archive = archive
  end

  def as_json(*)
    a = @archive
    {
      id: a.public_id,
      status: a.status,
      url: a.url,
      normalized_url: a.normalized_url,
      host: a.host,
      kind: a.kind,
      reference: a.reference,
      note: a.note,
      created_at: a.created_at&.iso8601,
      completed_at: a.completed_at&.iso8601,
      page_url: archive_url(a, host: default_host),
      problem: a.problem,
      captures: a.captures.map { |c| capture_json(c) }
    }
  end

  private

  def capture_json(capture)
    {
      id: capture.public_id,
      method: capture.method_name,
      status: capture.status,
      error: capture.error,
      error_code: capture.error_code,
      started_at: capture.started_at&.iso8601,
      finished_at: capture.finished_at&.iso8601,
      artifacts: capture.artifacts.map { |artifact| artifact_json(artifact) }
    }
  end

  def artifact_json(artifact)
    {
      id: artifact.public_id,
      role: artifact.role,
      filename: artifact.filename,
      content_type: artifact.content_type,
      byte_size: artifact.byte_size,
      sha256: artifact.sha256,
      download_url: artifact_url(artifact, host: default_host)
    }
  end

  def default_host
    Rails.application.routes.default_url_options[:host] || "localhost:3000"
  end
end
