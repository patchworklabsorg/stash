require "test_helper"

class ArchiveTest < ActiveSupport::TestCase
  test "normalizes the URL, keeps the original, and derives the host and kind" do
    archive = create_archive(url: "  HTTPS://GitHub.com/patchworklabsorg/stash?utm_source=x#readme ")

    assert_equal "HTTPS://GitHub.com/patchworklabsorg/stash?utm_source=x#readme", archive.url
    assert_equal "https://github.com/patchworklabsorg/stash", archive.normalized_url
    assert_equal "github.com", archive.host
    assert_equal "repo", archive.kind
    assert_equal "queued", archive.status
    assert_match(/\Aarc_/, archive.public_id)
  end

  test "refuses a URL that is not http" do
    archive = Archive.new(url: "javascript:alert(1)")

    assert_not archive.valid?
    assert_includes archive.errors[:url].join, "http"
  end

  test "copies reference.submission into submission_ref" do
    archive = create_archive(reference: { "patch" => "ganymede", "submission" => "sub_123" })

    assert_equal "sub_123", archive.submission_ref
    assert_nil create_archive(url: "https://example.org/x", reference: { "patch" => "ganymede" }).submission_ref
  end

  test "status follows the captures" do
    assert_equal "done", create_archive_with_captures({ "page" => "done", "git" => "done" }).status
    assert_equal "done", create_archive_with_captures({ "page" => "done", "file" => "skipped" }, url: "https://example.org/a").status
    assert_equal "partial", create_archive_with_captures({ "page" => "done", "git" => "failed" }, url: "https://example.org/b").status
    assert_equal "failed", create_archive_with_captures({ "page" => "failed", "git" => "failed" }, url: "https://example.org/c").status
    assert_equal "running", create_archive_with_captures({ "page" => "done", "git" => "running" }, url: "https://example.org/d").status
    assert_equal "running", create_archive_with_captures({ "page" => "running", "git" => "queued" }, url: "https://example.org/e").status
    assert_equal "queued", create_archive_with_captures({ "page" => "queued", "git" => "queued" }, url: "https://example.org/f").status
  end

  test "problem names the failed capture whose code matters most, and is nil without a failure" do
    archive = create_archive_with_captures({ "github" => "failed", "git" => "failed", "page" => "done" })
    archive.captures.find_by(method_name: "github").update!(error: "ToolFailed: GitHub answered 500", error_code: "tool_failed")
    archive.captures.find_by(method_name: "git").update!(error: "NotPublic: git clone: private", error_code: "not_public")

    problem = archive.problem
    assert_equal "not_public", problem[:code]
    assert_equal "git", problem[:method]
    assert_equal "NotPublic: git clone: private", problem[:message]
    assert_includes problem[:hint], "Ask the owner"

    assert_nil create_archive_with_captures({ "page" => "done" }).problem
  end

  test "a failed capture without a code reads as tool_failed" do
    archive = create_archive_with_captures({ "page" => "failed" })
    archive.captures.first.update!(error: "ToolFailed: Chromium died")

    assert_equal "tool_failed", archive.problem[:code]
  end

  test "completed_at is set only when finished" do
    assert_nil create_archive_with_captures({ "page" => "running" }).completed_at
    assert_not_nil create_archive_with_captures({ "page" => "done" }, url: "https://example.org/a").completed_at
  end

  test "for_url finds archives by the normalized URL" do
    archive = create_archive(url: "https://example.org/a/?b=2&a=1")

    assert_includes Archive.for_url("https://EXAMPLE.org/a?a=1&b=2"), archive
  end

  test "finds by public id" do
    archive = create_archive

    assert_equal archive, Archive.find_by_public_id!(archive.public_id)
  end
end
