require "test_helper"

# The page capturer against a fake browser: no Chromium runs in the tests. The fake records
# every CDP command, navigation, script and scroll in order, and writes empty files where the
# real browser would.
class Capturers::PageTest < ActiveSupport::TestCase
  class FakeNetwork
    def initialize(idle)
      @idle = idle
    end

    # Ferrum answers false at the deadline; it does not raise.
    def wait_for_idle(timeout:) = @idle

    # No responses recorded: the view gets nothing beyond the MHTML.
    def traffic = []
  end

  class FakeFrame
    def initialize(page) = @page = page
    def execute(script) = @page.execute(script)
  end

  class FakePage
    attr_reader :events, :files, :network
    attr_accessor :scroll_y

    def initialize(height:, idle: true, frames: 1)
      @height = height
      @events = []
      @files = []
      @network = FakeNetwork.new(idle)
      @frames = Array.new(frames) { FakeFrame.new(self) }
      @scroll_y = nil
    end

    def command(name, **params)
      @events << [ :command, name, params ]
      name == "Page.captureScreenshot" ? { "data" => Base64.strict_encode64("png") } : {}
    end

    def go_to(url) = @events << [ :go_to, url ]
    def title = "A page"
    def frames = @frames

    def evaluate(script, **)
      @events << [ :evaluate, script ]
      case script
      when /scrollHeight/ then @height
      when /fonts.status/ then "loaded"
      when /scrollY/ then @scroll_y || scrolls.last
      else true
      end
    end

    def execute(script)
      if script.include?("scrollTo")
        @events << [ :scroll, script[/top: (\d+)/, 1].to_i ]
      else
        @events << [ :execute, script ]
      end
    end

    def mhtml(path:) = write(path)
    def pdf(path:, **) = write(path)

    def scrolls = @events.filter_map { |event| event[1] if event[0] == :scroll }
    def commands = @events.filter_map { |event| event[1] if event[0] == :command }
    def screenshot_clip = @events.find { |event| event[0] == :command && event[1] == "Page.captureScreenshot" }&.dig(2, :clip)

    private

    def write(path)
      File.write(path, "x")
      @files << File.basename(path)
      @events << [ :write, File.basename(path) ]
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

  test "walks the page one viewport at a time, instantly, and returns to the top" do
    page = FakePage.new(height: 3000)
    run_capture(page)

    assert_equal [ 900, 1800, 2700, 3600, 0 ], page.scrolls
    assert_includes @capture.log, "scrolling 3000px in 4 steps"
    assert_includes @capture.log, "page is 3000px tall after the scroll"
    scroll = page.events.find { |event| event[0] == :scroll }
    assert scroll, "scrolls through scrollTo"
  end

  test "caps the walk on a very long page, and the screenshot at the Chromium limit" do
    page = FakePage.new(height: 900 * 500)
    run_capture(page)

    assert_equal Capturers::Page::SCROLL_STEPS + 1, page.scrolls.size
    assert_equal 0, page.scrolls.last
    assert_equal 16_384, page.screenshot_clip[:height]
    assert_includes @capture.log, "the screenshot is cut at 16384px of 450000px"
  end

  test "stops the walk when the window does not scroll" do
    page = FakePage.new(height: 5000)
    page.scroll_y = 0
    run_capture(page)

    assert_equal [ 900, 0 ], page.scrolls
    assert_includes @capture.log, "the page did not scroll"
  end

  test "pauses media and stops animation frames in every frame after the walk and before the files" do
    page = FakePage.new(height: 1800, frames: 2)
    run_capture(page)

    freezes = page.events.each_index.select { |i| page.events[i][0] == :execute && page.events[i][1].include?("requestAnimationFrame") }
    last_scroll = page.events.rindex { |event| event[0] == :scroll }
    first_write = page.events.index { |event| event[0] == :write }
    assert_equal 2, freezes.size, "one freeze per frame"
    assert_operator last_scroll, :<, freezes.first
    assert_operator freezes.last, :<, first_write
    assert_includes page.events[freezes.first][1], "media.pause()"
    assert_includes page.events, [ :command, "Animation.setPlaybackRate", { playbackRate: 0 } ]
  end

  test "writes the three files and returns them in role order" do
    outputs = run_capture(FakePage.new(height: 900))

    assert_equal %w[original screenshot rendition], outputs.map(&:role)
    assert_equal %w[page.mhtml page.png page.pdf], outputs.map { |o| File.basename(o.path) }
    assert_equal "png", File.read(File.join(@workdir, "page.png"))
    assert_equal({ x: 0, y: 0, width: 1440, height: 900, scale: 1 }, FakePage.new(height: 900).then { |p| run_capture(p); p.screenshot_clip })
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

  test "a renderer crash during the walk is not swallowed, and gets the second try" do
    crashing = FakePage.new(height: 3000)
    crashing.define_singleton_method(:execute) { |_script| raise Ferrum::BrowserError.new({ "message" => "Target crashed" }) }
    browsers = [ FakeBrowser.new(crashing), FakeBrowser.new(FakePage.new(height: 900)) ]
    outputs = nil
    stub_method(Capturers::Page, :new_browser, -> { browsers.shift }) do
      stub_method(Capturers::Page, :sleep_for, ->(_seconds) { }) do
        outputs = Capturers::Page.new(@capture, @workdir).call
      end
    end

    assert_equal 3, outputs.size
    assert_empty browsers
  end

  test "any other browser error fails the capture as a tool failure, once" do
    page = FakePage.new(height: 900)
    page.define_singleton_method(:mhtml) { |path:| raise Ferrum::BrowserError.new({ "message" => "No MHTML for this scheme" }) }

    error = assert_raises(Capturers::ToolFailed) { run_capture(page) }
    assert_includes error.message, "No MHTML for this scheme"
    assert_not_includes @capture.log, "(second try)"
  end

  test "logs when the network never goes idle, and captures as is" do
    outputs = run_capture(FakePage.new(height: 900, idle: false))

    assert_equal 3, outputs.size
    assert_includes @capture.log, "the page kept loading for"
    assert_includes @capture.log, "images kept loading after the scroll"
  end
end
