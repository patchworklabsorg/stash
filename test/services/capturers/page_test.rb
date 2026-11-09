require "test_helper"

# The page capturer against a fake browser: no Chromium runs in the tests. The fake records
# every CDP command, navigation, script and scroll in order, and writes empty files where the
# real browser would.
class Capturers::PageTest < ActiveSupport::TestCase
  class FakeNetwork
    def initialize(idle)
      @idle = idle
    end

    def wait_for_idle(timeout:)
      raise Ferrum::TimeoutError unless @idle
    end
  end

  class FakePage
    attr_reader :events, :files, :network

    def initialize(height:, idle: true)
      @height = height
      @events = []
      @files = []
      @network = FakeNetwork.new(idle)
    end

    def command(name, **params) = @events << [ :command, name, params ]
    def go_to(url) = @events << [ :go_to, url ]
    def title = "A page"

    def evaluate(script, **)
      @events << [ :evaluate, script ]
      case script
      when /scrollHeight/ then @height
      when /fonts.status/ then "loaded"
      else true
      end
    end

    def execute(script)
      @events << [ :scroll, script[/scrollTo\(0, (\d+)\)/, 1].to_i ]
    end

    def mhtml(path:) = write(path)
    def screenshot(path:, **) = write(path)
    def pdf(path:, **) = write(path)

    def scrolls = @events.filter_map { |event| event[1] if event[0] == :scroll }
    def commands = @events.filter_map { |event| event[1] if event[0] == :command }

    private

    def write(path)
      File.write(path, "x")
      @files << File.basename(path)
    end
  end

  class FakeBrowser
    attr_reader :quit_called

    def initialize(page)
      @page = page
    end

    def create_page = @page
    def quit = @quit_called = true
  end

  setup do
    @archive = create_archive(url: "https://example.org/story")
    @capture = @archive.captures.create!(method_name: "page", status: "running", position: 0)
    @workdir = Dir.mktmpdir
  end

  teardown do
    FileUtils.rm_rf(@workdir)
  end

  def run_capture(page)
    browser = FakeBrowser.new(page)
    outputs = nil
    stub_method(Capturers::Page, :new_browser, browser) do
      stub_method(Capturers::Page, :sleep_for, ->(_seconds) { }) do
        outputs = Capturers::Page.new(@capture, @workdir).call
      end
    end
    assert browser.quit_called, "the browser is closed"
    outputs
  end

  test "asks for reduced motion and fast animations before the page loads" do
    page = FakePage.new(height: 900)
    run_capture(page)

    first_navigation = page.events.index { |event| event[0] == :go_to }
    before = page.events.first(first_navigation)
    assert_includes before, [ :command, "Emulation.setEmulatedMedia", { features: [ { name: "prefers-reduced-motion", value: "reduce" } ] } ]
    assert_includes before, [ :command, "Animation.setPlaybackRate", { playbackRate: 50 } ]
  end

  test "walks the page one viewport at a time and returns to the top" do
    page = FakePage.new(height: 3000)
    run_capture(page)

    assert_equal [ 900, 1800, 2700, 3600, 0 ], page.scrolls
    assert_includes @capture.log, "scrolling 3000px in 4 steps"
  end

  test "caps the walk on a very long page" do
    page = FakePage.new(height: 900 * 500)
    run_capture(page)

    assert_equal Capturers::Page::SCROLL_STEPS + 1, page.scrolls.size
    assert_equal 0, page.scrolls.last
  end

  test "writes the three files and returns them in role order" do
    outputs = run_capture(FakePage.new(height: 900))

    assert_equal %w[original screenshot rendition], outputs.map(&:role)
    assert_equal %w[page.mhtml page.png page.pdf], outputs.map { |o| File.basename(o.path) }
  end

  test "tries once more in a new browser when the first one dies" do
    dead = FakePage.new(height: 900)
    dead.define_singleton_method(:go_to) { |_url| raise Ferrum::DeadBrowserError }
    browsers = [ FakeBrowser.new(dead), FakeBrowser.new(FakePage.new(height: 900)) ]
    outputs = nil
    stub_method(Capturers::Page, :new_browser, -> { browsers.shift }) do
      stub_method(Capturers::Page, :sleep_for, ->(_seconds) { }) do
        outputs = Capturers::Page.new(@capture, @workdir).call
      end
    end

    assert_equal 3, outputs.size
    assert_empty browsers, "both browsers were used"
    assert_includes @capture.log, "(second try)"
  end

  test "captures as is when the network never goes idle" do
    outputs = run_capture(FakePage.new(height: 900, idle: false))

    assert_equal 3, outputs.size
    assert_includes @capture.log, "the page kept loading for"
    assert_includes @capture.log, "images kept loading after the scroll"
  end
end
