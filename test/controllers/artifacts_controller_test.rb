require "test_helper"

class ArtifactsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @archive = create_archive_with_captures({ "page" => "done" })
    @artifact = @archive.captures.first.artifacts.create!(role: "screenshot", filename: "page.png",
      content_type: "image/png", byte_size: 3, sha256: "a" * 64)
    @artifact.file.attach(io: StringIO.new("png"), filename: "page.png", content_type: "image/png")
  end

  test "signed out goes to sign-in" do
    get artifact_path(@artifact)

    assert_redirected_to sign_in_path
  end

  # The Disk service (development, test, and production with STASH_STORAGE_SERVICE=disk) builds
  # its URL from the request, so this also proves ActiveStorage::SetCurrent is in place.
  test "a viewer is redirected to a signed storage URL, inline for an image" do
    sign_in_as(:viewer)

    get artifact_path(@artifact)

    assert_response :redirect
    assert_includes response.location, "/rails/active_storage/disk/"
    assert_match(/\Ainline;/, signed_disposition(response.location))
  end

  test "a file that is not an image or a PDF is a download" do
    @artifact.update!(content_type: "application/x-git-bundle", filename: "repo.bundle")
    sign_in_as(:viewer)

    get artifact_path(@artifact)

    assert_match(/\Aattachment;/, signed_disposition(response.location))
  end

  # The Disk service puts the disposition inside the signed token of the URL, not in the query.
  def signed_disposition(location)
    token = location[%r{/rails/active_storage/disk/([^/]+)/}, 1]
    ActiveStorage.verifier.verified(token, purpose: :blob_key).fetch("disposition")
  end

  test "an unknown id is 404" do
    sign_in_as(:viewer)

    get artifact_path("nope")
    assert_response :not_found
  end
end
