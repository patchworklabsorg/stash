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

  test "a resource from the network fills what the MHTML lacks, and the MHTML wins when both have it" do
    font = Capturers::Mhtml::Part.new(location: "https://example.org/js/app.js", content_type: "font/woff", body: "WOFF")
    other = Capturers::Mhtml::Part.new(location: "https://example.org/img/photo.png", content_type: "image/gif", body: "GIF")
    html = Capturers::Mhtml.inline(file_fixture("page.mhtml").to_s, resources: { font.location => font, other.location => other })

    assert_includes html, %(src="data:font/woff;base64,#{Base64.strict_encode64("WOFF")}")
    assert_includes html, %(src="data:image/png;base64,#{PNG}")
    assert_not_includes html, "image/gif"
  end

  test "each canvas becomes an image of what it showed, and one without an image stays" do
    path = File.join(Dir.mktmpdir, "c.mhtml")
    File.write(path, File.read(file_fixture("page.mhtml")).sub("<h1>A story</h1>",
      "<h1>A story</h1><canvas id=3D\"chart\" class=3D\"wide\" width=3D\"300\" height=3D\"150\" data-x=3D\"1\"></canvas><canvas></canvas>"))
    data = "data:image/png;base64,#{PNG}"

    html = Capturers::Mhtml.inline(path, canvases: [ data, nil ])

    assert_includes html, %(<img src="#{data}" alt="" id="chart" class="wide" width="300" height="150">)
    assert_includes html, "<canvas></canvas>"
    assert_not_includes html, "data-x"
  end

  test "a file that is not MHTML fails as a tool failure" do
    path = File.join(Dir.mktmpdir, "x.mhtml")
    File.write(path, "not mhtml at all")

    assert_raises(Capturers::ToolFailed) { Capturers::Mhtml.inline(path) }
  end
end
