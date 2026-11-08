require "test_helper"

class ArchivesControllerTest < ActionDispatch::IntegrationTest
  test "signed out goes to sign-in" do
    get archives_path

    assert_redirected_to sign_in_path
  end

  test "a person with no role gets 403 and no session" do
    sign_in_as

    assert_response :forbidden
    get archives_path
    assert_redirected_to sign_in_path
  end

  test "a viewer sees the list and an archive" do
    archive = create_archive_with_captures({ "page" => "done" })
    sign_in_as(:viewer)

    get archives_path
    assert_response :success
    assert_includes response.body, archive.url

    get archive_path(archive)
    assert_response :success
    assert_includes response.body, archive.public_id
    assert_not_includes response.body, "Delete this archive"
  end

  test "the list searches by URL, host and note" do
    create_archive(url: "https://example.org/alpha", note: "first")
    create_archive(url: "https://other.test/beta", note: "second")
    sign_in_as(:viewer)

    get archives_path(q: "other.test")
    assert_includes response.body, "https://other.test/beta"
    assert_not_includes response.body, "https://example.org/alpha"

    get archives_path(q: "first")
    assert_includes response.body, "https://example.org/alpha"
  end

  test "a viewer cannot archive a URL" do
    sign_in_as(:viewer)

    get new_archive_path
    assert_response :forbidden

    assert_no_difference("Archive.count") do
      post archives_path, params: { archive: { url: "https://example.org/" } }
    end
    assert_response :forbidden
  end

  test "an archivist archives a URL and the job is enqueued" do
    sign_in_as(:archivist, sub: "PWLARCHIV001")

    assert_enqueued_with(job: ArchiveJob) do
      post archives_path, params: { archive: { url: "https://example.org/project", note: "a note" } }
    end

    archive = Archive.sole
    assert_redirected_to archive_path(archive)
    assert_equal "PWLARCHIV001", archive.requested_by_sub
    assert_equal "a note", archive.note
    assert_nil archive.client_id
  end

  test "a bad URL shows the form again" do
    sign_in_as(:archivist)

    post archives_path, params: { archive: { url: "ftp://example.org/x" } }

    assert_response :unprocessable_content
    assert_includes response.body, "must be an http or https URL"
  end

  test "an archivist runs an archive again" do
    archive = create_archive_with_captures({ "page" => "done" })
    sign_in_as(:archivist, sub: "PWLARCHIV001")

    assert_enqueued_with(job: ArchiveJob) { post rerun_archive_path(archive) }

    assert_redirected_to archive_path(archive)
    assert_empty archive.reload.captures
    assert_equal "queued", archive.status
    assert_equal "archive.rerun", AuditEvent.sole.action
  end

  test "only an admin deletes, and only with a reason" do
    archive = create_archive_with_captures({ "page" => "done" })

    sign_in_as(:archivist)
    delete archive_path(archive), params: { reason: "test" }
    assert_response :forbidden

    sign_in_as(:admin, sub: "PWLADMIN0001")
    delete archive_path(archive)
    assert_redirected_to archive_path(archive)
    assert Archive.exists?(archive.id)

    delete archive_path(archive), params: { reason: "a duplicate" }
    assert_redirected_to archives_path
    assert_not Archive.exists?(archive.id)

    event = AuditEvent.sole
    assert_equal "archive.deleted", event.action
    assert_equal "PWLADMIN0001", event.actor_sub
    assert_equal archive.public_id, event.subject_public_id
    assert_equal "a duplicate", event.reason
    assert_equal archive.url, event.details["url"]
  end

  test "an unknown id, a raw UUID and a numeric id are 404" do
    archive = create_archive
    sign_in_as(:viewer)

    get archive_path("nope")
    assert_response :not_found

    get archive_path(archive.id)
    assert_response :not_found

    get archive_path(1)
    assert_response :not_found

    get archive_path(archive.public_id)
    assert_response :success
  end

  test "routes hold the encoded id without the prefix" do
    archive = create_archive

    assert_equal "/archives/#{archive.encoded_id}", archive_path(archive)
    assert_not_includes archive_path(archive), "arc_"
  end
end
