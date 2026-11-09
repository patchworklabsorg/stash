require "test_helper"

# The document capturer against stubbed HTTP (WebMock). No LibreOffice runs here: the PDF cases
# stop before the conversion.
class Capturers::DocumentTest < ActiveSupport::TestCase
  DECK = "https://docs.google.com/presentation/d/1AbCdEfGhIjKlMnOpQrStUvWxYz0123456789abcd/edit".freeze

  setup do
    @workdir = Dir.mktmpdir
  end

  teardown do
    FileUtils.rm_rf(@workdir)
  end

  def capture_for(url)
    archive = create_archive(url: url)
    archive.captures.create!(method_name: "document", status: "running", position: 0)
  end

  test "a Google deck that is not shared fails as not_public, with what the owner has to do" do
    stub_request(:get, %r{docs\.google\.com/presentation/d/.*/export/pptx}).to_return(status: 404, body: "")
    capture = capture_for(DECK)

    error = assert_raises(Capturers::NotPublic) { Capturers::Document.new(capture, @workdir).call }

    assert_equal "not_public", error.code
    assert_equal 404, error.http_status
    assert_includes error.message, "Google answered 404 for the Google Slides deck"
    assert_includes error.message, "Ask the owner to share it"
  end

  test "a Google deck behind a sign-in (401) fails as not_public too" do
    stub_request(:get, %r{docs\.google\.com/presentation/d/.*/export/pptx}).to_return(status: 401, body: "")
    capture = capture_for(DECK)

    error = assert_raises(Capturers::NotPublic) { Capturers::Document.new(capture, @workdir).call }
    assert_equal 401, error.http_status
  end

  test "a Google deck that redirects to the sign-in page fails as not_public, not as a done capture" do
    stub_request(:get, %r{docs\.google\.com/presentation/d/.*/export/pptx})
      .to_return(status: 302, headers: { "Location" => "https://accounts.google.com/ServiceLogin?continue=x" })
    stub_request(:get, %r{accounts\.google\.com/ServiceLogin})
      .to_return(status: 200, body: "<html><title>Sign in - Google Accounts</title></html>", headers: { "Content-Type" => "text/html; charset=utf-8" })
    capture = capture_for(DECK)

    error = assert_raises(Capturers::NotPublic) { Capturers::Document.new(capture, @workdir).call }

    assert_includes error.message, "Google answered a sign-in page for the Google Slides deck"
    assert_includes capture.log, "not the pptx"
  end

  test "a Google rate limit stays blocked, so nobody is told to share a shared deck" do
    stub_request(:get, %r{docs\.google\.com/presentation/d/.*/export/pptx}).to_return(status: 429, body: "")
    capture = capture_for(DECK)

    error = assert_raises(Capturers::Blocked) { Capturers::Document.new(capture, @workdir).call }
    assert_equal 429, error.http_status
  end

  test "a shared Google deck exports both files" do
    stub_request(:get, %r{docs\.google\.com/presentation/d/.*/export/pptx})
      .to_return(status: 200, body: "PK deck", headers: { "Content-Type" => "application/vnd.openxmlformats-officedocument.presentationml.presentation" })
    stub_request(:get, %r{docs\.google\.com/presentation/d/.*/export/pdf})
      .to_return(status: 200, body: "%PDF-1.4", headers: { "Content-Type" => "application/pdf" })
    capture = capture_for(DECK)

    outputs = Capturers::Document.new(capture, @workdir).call

    assert_equal %w[original rendition], outputs.map(&:role)
    assert_includes capture.log, "Google export: 7 bytes as pptx"
  end

  test "a direct file that is gone fails as not_found" do
    stub_request(:get, "https://example.org/report.pdf").to_return(status: 404, body: "")
    capture = capture_for("https://example.org/report.pdf")

    error = assert_raises(Capturers::NotFound) { Capturers::Document.new(capture, @workdir).call }
    assert_equal "GET example.org answered 404", error.message
  end

  test "a direct file behind a refusal fails as blocked" do
    stub_request(:get, "https://example.org/report.pdf").to_return(status: 403, body: "")
    capture = capture_for("https://example.org/report.pdf")

    assert_raises(Capturers::Blocked) { Capturers::Document.new(capture, @workdir).call }
  end

  test "a direct PDF is stored as served, with no conversion" do
    stub_request(:get, "https://example.org/report.pdf")
      .to_return(status: 200, body: "%PDF-1.4 report", headers: { "Content-Type" => "application/pdf" })
    capture = capture_for("https://example.org/report.pdf")

    outputs = Capturers::Document.new(capture, @workdir).call

    assert_equal [ "original" ], outputs.map(&:role)
    assert_equal "report.pdf", outputs.first.filename
  end
end
