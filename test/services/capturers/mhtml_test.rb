require "test_helper"

class Capturers::MhtmlTest < ActiveSupport::TestCase
  PNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==".freeze

  setup do
    @html = Capturers::Mhtml.inline(file_fixture("page.mhtml").to_s)
  end

  test "keeps the document and inlines the images it carries" do
    assert_includes @html, "<h1>A story</h1>"
    assert_includes @html, %(src="data:image/png;base64,#{PNG}")
    assert_not_includes @html, %(src="/img/photo.png")
  end

  test "inlines the stylesheet, with the urls inside it resolved" do
    assert_match %r{href="data:text/css;base64,[A-Za-z0-9+/=]+"}, @html
    css = Base64.decode64(@html[%r{href="data:text/css;base64,([A-Za-z0-9+/=]+)"}, 1])
    assert_includes css, "rebeccapurple"
    assert_includes css, "url(\"data:image/png;base64,#{PNG}\")"
  end

  test "resolves urls in inline styles and in srcset" do
    assert_includes @html, "background: url(data:image/png;base64,#{PNG})"
    assert_includes @html, %(srcset="data:image/png;base64,#{PNG} 1x, data:image/png;base64,#{PNG} 2x")
  end

  test "links are absolute, open in a new tab and send no referrer" do
    assert_includes @html, %(<a href="https://example.org/next" target="_blank" rel="noopener noreferrer nofollow">Next</a>)
    assert_includes @html, %(<a href="https://other.example/x" target="_blank" rel="noopener noreferrer nofollow">Other</a>)
  end

  test "a resource the MHTML lacks keeps its absolute url, and scripts are left in place" do
    assert_includes @html, %(src="https://example.org/js/app.js")
  end

  test "adds a base and a note" do
    assert_includes @html, %(<base href="https://example.org/story/" target="_blank">)
    assert_includes @html, "Archived by Stash"
  end

  test "a file that is not MHTML fails as a tool failure" do
    path = File.join(Dir.mktmpdir, "x.mhtml")
    File.write(path, "not mhtml at all")

    assert_raises(Capturers::ToolFailed) { Capturers::Mhtml.inline(path) }
  end
end
