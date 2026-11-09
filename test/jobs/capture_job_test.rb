require "test_helper"
require "support/fake_capturer"

class CaptureJobTest < ActiveJob::TestCase
  include FakeCapturer

  # Active Storage uploads a file after the transaction commits. A transactional test never
  # commits, so these tests run outside one and clean up themselves.
  self.use_transactional_tests = false

  setup do
    @archive = create_archive
    @capture = @archive.captures.create!(method_name: "page")
  end

  teardown do
    Archive.destroy_all
  end

  test "stores the capturer's outputs as artifacts and finishes the capture and the archive" do
    with_capturer(FakeCapturer::Writes) { CaptureJob.perform_now(@capture) }

    @capture.reload
    assert_equal "done", @capture.status
    assert_not_nil @capture.started_at
    assert_not_nil @capture.finished_at
    assert_includes @capture.log, "fake: writing one file"
    assert_includes @capture.log, "stored original hello.txt"

    artifact = @capture.artifacts.sole
    assert_equal "original", artifact.role
    assert_equal "hello.txt", artifact.filename
    assert_equal "text/plain", artifact.content_type
    assert_equal "hello from https://example.org/project\n".bytesize, artifact.byte_size
    assert_equal Digest::SHA256.hexdigest("hello from https://example.org/project\n"), artifact.sha256
    assert artifact.file.attached?
    assert_equal "hello from https://example.org/project\n", artifact.file.download
    assert_match(/\Aart_/, artifact.public_id)

    assert_equal "done", @archive.reload.status
  end

  test "a Skip makes the capture skipped" do
    with_capturer(FakeCapturer::Skips) { CaptureJob.perform_now(@capture) }

    assert_equal "skipped", @capture.reload.status
    assert_equal "does not apply", @capture.error
    assert_nil @capture.error_code
  end

  test "a capturer error makes the capture failed, with the reason and its code" do
    with_capturer(FakeCapturer::Fails) { CaptureJob.perform_now(@capture) }

    assert_equal "failed", @capture.reload.status
    assert_equal "ToolFailed: the tool said no", @capture.error
    assert_equal "tool_failed", @capture.error_code
    assert_equal "failed", @archive.reload.status
    assert_equal "tool_failed", @archive.problem[:code]
  end

  test "a private source fails the capture with the not_public code" do
    with_capturer(FakeCapturer::Private) { CaptureJob.perform_now(@capture) }

    assert_equal "failed", @capture.reload.status
    assert_equal "not_public", @capture.error_code
    assert_includes @capture.error, "NotPublic: ask the owner"
    assert_equal "not_public", @archive.reload.problem[:code]
    assert_includes @archive.problem[:hint], "Ask the owner to share it"
  end

  test "an unexpected exception fails the capture and is raised again" do
    assert_raises(ArgumentError) { with_capturer(FakeCapturer::Explodes) { CaptureJob.perform_now(@capture) } }

    assert_equal "failed", @capture.reload.status
    assert_includes @capture.error, "ArgumentError"
    assert_equal "unexpected", @capture.error_code
  end

  test "a finished capture is not run again" do
    @capture.update!(status: "done")

    with_capturer(FakeCapturer::Writes) { CaptureJob.perform_now(@capture) }

    assert_empty @capture.reload.artifacts
  end
end
