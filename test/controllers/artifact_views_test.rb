require "test_helper"

# The viewer for a `view` artifact: the page around the frame, and the frame itself with the
# policy that keeps the archived document from running anything.
class ArtifactViewsTest < ActionDispatch::IntegrationTest
  setup do
    @archive = create_archive_with_captures({ "page" => "done" }, url: "https://example.org/story/")
    capture = @archive.captures.first
    html = "<!DOCTYPE html><html><head><title>A story</title></head><body><h1>A story</h1><script>alert(1)</script></body></html>"
    @view = capture.artifacts.create!(role: "view", filename: "page.html", content_type: "text/html",
      byte_size: html.bytesize, sha256: Digest::SHA256.hexdigest(html))
    @view.file.attach(io: StringIO.new(html), filename: "page.html", content_type: "text/html")
    @screenshot = capture.artifacts.create!(role: "screenshot", filename: "page.png", content_type: "image/png",
      byte_size: 3, sha256: "a" * 64)
    @screenshot.file.attach(io: StringIO.new("png"), filename: "page.png", content_type: "image/png")
  end

  test "signed out goes to sign-in" do
    get view_artifact_path(@view)
    assert_redirected_to sign_in_path

    get frame_artifact_path(@view)
    assert_redirected_to sign_in_path
  end

  test "a viewer sees the page around the frame" do
    sign_in_as(:viewer)

    get view_artifact_path(@view)

    assert_response :success
    assert_select "iframe[src=?][sandbox=?]", frame_artifact_path(@view), "allow-popups allow-popups-to-escape-sandbox"
    assert_select "a[href=?]", archive_path(@archive)
    assert_includes response.body, "Scripts do not run"
  end

  test "the frame serves the document inline with a policy that runs nothing" do
    sign_in_as(:viewer)

    get frame_artifact_path(@view)

    assert_response :success
    assert_equal "text/html; charset=utf-8", response.media_type + "; charset=utf-8"
    assert_includes response.body, "<h1>A story</h1>"
    csp = response.headers["Content-Security-Policy"]
    assert_includes csp, "default-src 'none'"
    assert_includes csp, "img-src data:;"
    assert_includes csp, "sandbox allow-popups allow-popups-to-escape-sandbox"
    assert_not_includes csp, "script-src"
    assert_not_includes csp, "https:"
    assert_equal "SAMEORIGIN", response.headers["X-Frame-Options"]
    assert_equal "no-referrer", response.headers["Referrer-Policy"]
    assert_match(/\Ainline/, response.headers["Content-Disposition"])
  end

  test "an artifact that is not a view has no viewer" do
    sign_in_as(:viewer)

    get view_artifact_path(@screenshot)
    assert_response :not_found

    get frame_artifact_path(@screenshot)
    assert_response :not_found
  end

  test "the archive page offers the viewer when a capture has a view" do
    sign_in_as(:viewer)

    get archive_path(@archive)

    assert_response :success
    assert_select "a[href=?]", view_artifact_path(@view), text: /View the archived page/
  end
end
