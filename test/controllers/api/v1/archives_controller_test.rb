require "test_helper"
require "support/fake_weave"

class Api::V1::ArchivesControllerTest < ActionDispatch::IntegrationTest
  include FakeWeave

  TOKEN = "patch-app-token".freeze

  def post_archive(token: TOKEN, **body)
    post api_v1_archives_path, params: body.to_json,
      headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
  end

  test "no token is 401" do
    post api_v1_archives_path, params: { url: "https://example.org/" }.to_json, headers: { "Content-Type" => "application/json" }

    assert_response :unauthorized
    assert_equal "invalid_token", response.parsed_body["error"]
  end

  test "an inactive token is 401" do
    with_fake_weave do
      stub_introspection(token: TOKEN, active: false)
      post_archive(url: "https://example.org/")
    end

    assert_response :unauthorized
  end

  test "a token without the stash scope is 403" do
    with_fake_weave do
      stub_introspection(token: TOKEN, scope: "quilt")
      post_archive(url: "https://example.org/")
    end

    assert_response :forbidden
    assert_equal "insufficient_scope", response.parsed_body["error"]
  end

  test "Weave down is 503" do
    with_fake_weave do
      stub_introspection(token: TOKEN, status: 500)
      post_archive(url: "https://example.org/")
    end

    assert_response :service_unavailable
  end

  test "creates an archive and enqueues the job" do
    with_fake_weave do
      stub_introspection(token: TOKEN, scope: "stash")
      assert_enqueued_with(job: ArchiveJob) do
        post_archive(url: "https://github.com/patchworklabsorg/stash", note: "from krater",
          reference: { patch: "ganymede", submission: "sub_1" })
      end
    end

    assert_response :created
    body = response.parsed_body
    archive = Archive.sole
    assert_equal archive.public_id, body["id"]
    assert_equal "queued", body["status"]
    assert_equal "repo", body["kind"]
    assert_equal({ "patch" => "ganymede", "submission" => "sub_1" }, body["reference"])
    assert_equal FakeWeave::PATCH_APP_CLIENT_ID, archive.client_id
    assert_nil archive.requested_by_sub
    assert_equal [], body["captures"]
  end

  test "a second POST for the same submission and URL returns the first archive with 200" do
    with_fake_weave do
      stub_introspection(token: TOKEN, scope: "stash")
      post_archive(url: "https://example.org/p", reference: { submission: "sub_1" })
      first = response.parsed_body["id"]

      assert_no_difference("Archive.count") do
        post_archive(url: "https://EXAMPLE.org/p/", reference: { submission: "sub_1" })
      end
      assert_response :ok
      assert_equal first, response.parsed_body["id"]

      post_archive(url: "https://example.org/p", reference: { submission: "sub_2" })
      assert_response :created
    end
  end

  test "an invalid URL is 422" do
    with_fake_weave do
      stub_introspection(token: TOKEN, scope: "stash")
      post_archive(url: "nope")
    end

    assert_response :unprocessable_content
    assert_equal "invalid", response.parsed_body["error"]
  end

  test "show returns the archive with captures and artifacts" do
    archive = create_archive_with_captures({ "page" => "done" })
    artifact = archive.captures.first.artifacts.create!(role: "original", filename: "page.mhtml",
      content_type: "multipart/related", byte_size: 3, sha256: "a" * 64)
    artifact.file.attach(io: StringIO.new("abc"), filename: "page.mhtml", content_type: "multipart/related")

    with_fake_weave do
      stub_introspection(token: TOKEN, scope: "stash")
      get api_v1_archive_path(archive.public_id), headers: { "Authorization" => "Bearer #{TOKEN}" }
    end

    assert_response :success
    body = response.parsed_body
    assert_equal "done", body["status"]
    capture = body["captures"].sole
    assert_equal "page", capture["method"]
    art = capture["artifacts"].sole
    assert_equal artifact.public_id, art["id"]
    assert_includes art["download_url"], "/artifacts/#{artifact.public_id}"
  end

  test "show for an unknown id is 404" do
    with_fake_weave do
      stub_introspection(token: TOKEN, scope: "stash")
      get api_v1_archive_path("arc_nope"), headers: { "Authorization" => "Bearer #{TOKEN}" }
    end

    assert_response :not_found
  end

  test "index lists the archives of a URL" do
    a = create_archive(url: "https://example.org/p?utm_source=x")
    create_archive(url: "https://example.org/other")

    with_fake_weave do
      stub_introspection(token: TOKEN, scope: "stash")
      get api_v1_archives_path(url: "https://example.org/p"), headers: { "Authorization" => "Bearer #{TOKEN}" }
    end

    assert_response :success
    assert_equal [ a.public_id ], response.parsed_body["archives"].map { |x| x["id"] }
  end
end
