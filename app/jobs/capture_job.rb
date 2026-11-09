require "digest"

# Runs one capture: makes a work directory, runs the capturer, stores its outputs as artifacts,
# and updates the capture and the archive. The work directory is always deleted.
#
# A capture that raises Capturers::Skip becomes skipped. Any other Capturers::Error becomes
# failed with the message in `error`. An unexpected exception also fails the capture, and is
# raised again so GoodJob records it.
class CaptureJob < ApplicationJob
  queue_as :captures

  def perform(capture)
    return if capture.finished?

    capture.update!(status: "running", started_at: Time.current, error: nil, error_code: nil)
    Dir.mktmpdir("stash-#{capture.method_name}-") do |workdir|
      outputs = capture.capturer.new(capture, workdir).call
      store(capture, outputs)
    end
    finish(capture, "done")
  rescue Capturers::Skip => e
    finish(capture, "skipped", error: e.message)
  rescue Capturers::Error => e
    finish(capture, "failed", error: "#{e.class.name.demodulize}: #{e.message}", error_code: e.code)
  rescue StandardError => e
    finish(capture, "failed", error: "#{e.class}: #{e.message.to_s.first(500)}", error_code: "unexpected")
    raise
  end

  private

  def store(capture, outputs)
    outputs.each do |out|
      sha = Digest::SHA256.file(out.path).hexdigest
      artifact = capture.artifacts.build(role: out.role, filename: out.filename, content_type: out.content_type,
        byte_size: File.size(out.path), sha256: sha)
      artifact.file.attach(io: File.open(out.path, "rb"), filename: out.filename, content_type: out.content_type,
        identify: false)
      artifact.save!
      capture.log!("stored #{out.role} #{out.filename} (#{artifact.byte_size} bytes, sha256 #{sha.first(12)})")
    end
  end

  def finish(capture, status, error: nil, error_code: nil)
    # An error class that is not in CODES (a bare Capturers::Error, a new subclass) must not
    # leave the capture running on a validation error.
    error_code = "unexpected" if error_code && Capturers::CODES.exclude?(error_code)
    capture.update!(status: status, error: error, error_code: error_code, finished_at: Time.current)
    capture.archive.refresh_status!
  end
end
