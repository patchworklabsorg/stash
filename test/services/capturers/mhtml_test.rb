require "test_helper"

class Capturers::MhtmlTest < ActiveSupport::TestCase
  PNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==".freeze
  DATA_PNG = "data:image/png;base64,#{PNG}".freeze

  setup do
    @html = Capturers::Mhtml.inline(file_fixture("page.mhtml").to_s)
    @doc = Nokogiri::HTML5.parse(@html)
  end

  # An MHTML like the fixture, with the document body replaced.
  def mhtml_with(body)
    path = File.join(Dir.mktmpdir, "x.mhtml")
    source = File.read(file_fixture("page.mhtml"))
    document = source[/<!DOCTYPE html>.*?<\/html>/m]
    File.write(path, source.sub(document, body.gsub("=", "=3D")))
    path
  end

  def inline_body(body, **options)
    Nokogiri::HTML5.parse(Capturers::Mhtml.inline(mhtml_with(body), **options))
  end

  test "keeps the document and inlines the images it carries" do
    assert_equal "A story", @doc.at_css("h1").text
    assert_equal DATA_PNG, @doc.at_css("img[alt=photo]")["src"]
  end

  test "inlines the stylesheet, with the urls inside it resolved" do
    href = @doc.at_css("link[rel=stylesheet]")["href"]
    assert_match %r{\Adata:text/css;base64,}, href
    css = Base64.decode64(href.split(",", 2).last)
    assert_includes css, "rebeccapurple"
    assert_includes css, "url(\"#{DATA_PNG}\")"
  end

  test "resolves urls in inline styles and in srcset" do
    assert_includes @doc.at_css("style").content, "background: url(#{DATA_PNG})"
    assert_equal "#{DATA_PNG} 1x, #{DATA_PNG} 2x", @doc.at_css("img[alt=two]")["srcset"]
  end

  test "links are absolute, open in a new tab and send no referrer" do
    links = @doc.css("a")
    assert_equal [ "https://example.org/next", "https://other.example/x" ], links.map { |a| a["href"] }
    assert_equal [ "_blank" ], links.map { |a| a["target"] }.uniq
    assert_equal [ "noopener noreferrer nofollow" ], links.map { |a| a["rel"] }.uniq
  end

  test "scripts are removed, and a resource the MHTML lacks keeps its absolute url" do
    assert_empty @doc.css("script")
    doc = inline_body(%(<html><head></head><body><img src="/img/missing.png"></body></html>))
    assert_equal "https://example.org/img/missing.png", doc.at_css("img")["src"]
  end

  test "adds a note and drops the page's own base after using it" do
    assert_includes @html, "Archived by Stash"
    assert_empty @doc.css("base")

    doc = inline_body(%(<html><head><base href="https://cdn.example/root/"></head><body><a href="x">x</a><img src="i.png"></body></html>))
    assert_equal "https://cdn.example/root/x", doc.at_css("a")["href"]
    assert_equal "https://cdn.example/root/i.png", doc.at_css("img")["src"]
    assert_empty doc.css("base")
  end

  test "a resource from the network fills what the MHTML lacks, and the MHTML wins when both have it" do
    font = Capturers::Mhtml::Part.new(location: "https://example.org/fonts/a.woff", content_type: "font/woff", body: "WOFF")
    other = Capturers::Mhtml::Part.new(location: "https://example.org/img/photo.png", content_type: "image/gif", body: "GIF")
    doc = inline_body(%(<html><head><style>@font-face { src: url("/fonts/a.woff"); }</style></head><body><img src="/img/photo.png"></body></html>),
      resources: { font.location => font, other.location => other })

    assert_includes doc.at_css("style").content, %(url("data:font/woff;base64,#{Base64.strict_encode64("WOFF")}"))
    assert_equal DATA_PNG, doc.at_css("img")["src"]
  end

  test "each canvas becomes an image of what it showed, and one without an image stays" do
    doc = inline_body(%(<html><body><canvas id="chart" class="wide" width="300" height="150" data-x="1" aria-hidden="true"></canvas><canvas></canvas></body></html>),
      canvases: [ DATA_PNG, nil ])

    img = doc.at_css("img")
    assert_equal [ DATA_PNG, "chart", "wide", "300", "150", "true", nil ],
      [ img["src"], img["id"], img["class"], img["width"], img["height"], img["aria-hidden"], img["data-x"] ]
    assert_equal 1, doc.css("canvas").size
  end

  test "the copy makes no network request of its own: refresh, referrer and link hints are removed" do
    doc = inline_body(<<~HTML)
      <html><head>
        <meta http-equiv="refresh" content="0;url=https://beacon.example/?v=1">
        <META HTTP-EQUIV=Refresh CONTENT="0;url=https://beacon.example/?v=2">
        <meta name="referrer" content="unsafe-url">
        <meta http-equiv="x-dns-prefetch-control" content="on">
        <meta name="viewport" content="width=device-width">
        <link rel="preconnect" href="https://t.example">
        <link rel="dns-prefetch" href="https://t.example">
        <link rel="preload" href="https://t.example/f.woff" as="font">
        <link rel="icon" href="/icon.png">
      </head><body><noscript><meta http-equiv="refresh" content="0;url=https://beacon.example/"></noscript>
      <a href="https://x.example/" ping="https://beacon.example/p" onclick="alert(1)">x</a></body></html>
    HTML

    assert_equal [ "viewport" ], doc.css("meta").map { |m| m["name"] || m["http-equiv"] }
    assert_equal [ "icon" ], doc.css("link").map { |l| l["rel"] }
    assert_nil doc.at_css("a")["ping"]
    assert_nil doc.at_css("a")["onclick"]
  end

  test "link attributes in any spelling end up safe, and a link is never a data or javascript url" do
    doc = inline_body(<<~HTML)
      <html><body>
        <a href="https://evil.example/" rel=opener target=_top>one</a>
        <a href="https://evil.example/" REL = "opener" TARGET = "_parent">two</a>
        <a href="/next">three</a>
        <a href="#top">four</a>
        <a href="javascript:alert(1)">five</a>
        <a href="data:text/html,<b>x</b>">six</a>
      </body></html>
    HTML

    links = doc.css("a")
    assert_equal [ "_blank" ], links.map { |a| a["target"] }.uniq
    assert_equal [ "noopener noreferrer nofollow" ], links.map { |a| a["rel"] }.uniq
    # /next is also a text/html part in a real MHTML (an iframe document); the link stays a URL, never a data: URL.
    assert_equal "https://example.org/next", links[2]["href"]
    assert_equal "#top", links[3]["href"]
    assert_nil links[4]["href"]
    assert_nil links[5]["href"]
  end

  test "a data url in srcset and a non-ascii path both survive" do
    part = Capturers::Mhtml::Part.new(location: "https://example.org/img/caf%C3%A9.png", content_type: "image/png", body: "cafe")
    doc = inline_body(%(<html><body><img srcset="#{DATA_PNG} 1x, /img/photo.png 2x"><img src="/img/café.png" alt="c"></body></html>),
      resources: { part.location => part })

    assert_equal "#{DATA_PNG} 1x, #{DATA_PNG} 2x", doc.at_css("img")["srcset"]
    assert_equal "data:image/png;base64,#{Base64.strict_encode64("cafe")}", doc.at_css("img[alt=c]")["src"]
  end

  test "a part is encoded once however often the page uses it, and a huge part is left as a url" do
    big = Capturers::Mhtml::Part.new(location: "https://example.org/big.png", content_type: "image/png", body: "x" * (Capturers::Mhtml::MAX_PART_BYTES + 1))
    doc = inline_body(%(<html><body><img src="/big.png"><img src="/img/photo.png"><img src="/img/photo.png"></body></html>),
      resources: { big.location => big })

    assert_equal "https://example.org/big.png", doc.css("img")[0]["src"]
    assert_equal [ DATA_PNG, DATA_PNG ], doc.css("img")[1..].map { |i| i["src"] }
  end

  test "a hostile stylesheet does not stall the rewrite" do
    css = "a { background: " + ("url(" * 20_000) + " }"
    doc = nil
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    doc = inline_body(%(<html><head><style>#{css}</style></head><body></body></html>))
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

    assert_operator elapsed, :<, 2
    assert_includes doc.at_css("style").content, "url("
  end

  test "a file that is not MHTML fails as a tool failure" do
    path = File.join(Dir.mktmpdir, "x.mhtml")
    File.write(path, "not mhtml at all")

    assert_raises(Capturers::ToolFailed) { Capturers::Mhtml.inline(path) }
  end
end
