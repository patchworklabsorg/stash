module Capturers
  # A rendered web page in headless Chromium, through Ferrum: the MHTML of the page as loaded
  # (original), a full-page PNG (screenshot) and a print PDF (rendition). One browser, one load.
  #
  # The browser runs with no sandbox inside the container (Docker gives the isolation), with a
  # fixed viewport, and with JavaScript on, because most pages are empty without it. It never
  # signs in anywhere and sends no cookies.
  #
  # Many pages draw themselves as the reader scrolls: sections start at opacity 0 and fade in
  # through an IntersectionObserver, images load lazily, animations run for seconds. A capture
  # of the page as first loaded is then mostly blank below the fold. So before the files are
  # written, the capturer asks for reduced motion, runs animations fast, walks the whole page
  # once in viewport steps, and returns to the top. See docs/design.md, "Dynamic pages".
  class Page < Base
    VIEWPORT = [ 1440, 900 ].freeze
    LOAD_TIMEOUT = 60
    IDLE_TIMEOUT = 10
    # The walk down the page: at most this many steps of one viewport each, this long apart.
    SCROLL_STEPS = 60
    SCROLL_PAUSE = 0.25
    # After the walk, time for the last reveals and the images they started.
    SETTLE = 1.0

    def call
      @started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      attempts = 0
      begin
        attempts += 1
        log("Chromium: loading #{url}#{" (second try)" if attempts > 1}")
        with_browser { |browser| capture_in(browser) }
      rescue Ferrum::DeadBrowserError => e
        # A heavy page can take the renderer down once. One more try, in a new browser.
        retry if attempts < 2
        raise ToolFailed, "Chromium: #{e.class}: #{e.message.to_s.first(300)}"
      end

      [
        output("original", "page.mhtml", content_type: "multipart/related"),
        output("screenshot", "page.png", content_type: "image/png"),
        output("rendition", "page.pdf", content_type: "application/pdf")
      ]
    rescue Ferrum::Error => e
      raise ToolFailed, "Chromium: #{e.class}: #{e.message.to_s.first(300)}"
    end

    private

    def capture_in(browser)
      page = browser.create_page
      calm(page)
      page.go_to(url)
      wait_for_idle(page, "the page kept loading")
      log("title: #{page.title.to_s.first(200)} (#{elapsed}s)")

      reveal(page)
      wait_for_idle(page, "images kept loading after the scroll")
      self.class.sleep_for(SETTLE)
      freeze(page)

      log("saving the MHTML (#{elapsed}s)")
      page.mhtml(path: path("page.mhtml"))
      log("saving the screenshot (#{elapsed}s)")
      page.screenshot(path: path("page.png"), full: true)
      log("saving the PDF (#{elapsed}s)")
      page.pdf(path: path("page.pdf"), format: :A4, print_background: true)
      log("done (#{elapsed}s)")
    end

    def elapsed
      (Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started).round(1)
    end

    # Before the page loads: ask for reduced motion, so pages that honor it skip their
    # entrance animations, and run the ones that remain at 50x so they are over in time.
    def calm(page)
      page.command("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "reduce" } ])
      page.command("Animation.enable")
      page.command("Animation.setPlaybackRate", playbackRate: 50)
    rescue Ferrum::Error => e
      log("could not set reduced motion: #{e.message.to_s.first(120)}")
    end

    # Walks down the page one viewport at a time, so observers fire and lazy images load,
    # then returns to the top. Waits for fonts first, so text does not reflow in the capture.
    def reveal(page)
      wait_for_fonts(page)
      height = page.evaluate("document.documentElement.scrollHeight").to_i
      step = VIEWPORT.last
      steps = [ (height.to_f / step).ceil, SCROLL_STEPS ].min
      log("scrolling #{height}px in #{steps} steps")
      steps.times do |i|
        page.execute("window.scrollTo(0, #{(i + 1) * step})")
        self.class.sleep_for(SCROLL_PAUSE)
      end
      page.execute("window.scrollTo(0, 0)")
      self.class.sleep_for(SCROLL_PAUSE)
      final = page.evaluate("document.documentElement.scrollHeight").to_i
      log("page is #{final}px tall after the scroll") if final != height
    rescue Ferrum::Error => e
      log("the scroll stopped early: #{e.message.to_s.first(120)}")
    end

    # Stops the page from drawing new frames while the files are written: pauses media and
    # takes away requestAnimationFrame, so a render loop (a WebGL scene, a carousel) keeps its
    # last frame. Without this, a software-rendered WebGL scene made one screenshot take
    # 16 minutes, because every frame it kept drawing had to be composited first.
    def freeze(page)
      page.execute(<<~JS)
        document.querySelectorAll("video, audio").forEach((media) => { try { media.pause(); } catch (_) {} });
        window.requestAnimationFrame = () => 0;
        window.cancelAnimationFrame = () => {};
      JS
    rescue Ferrum::Error => e
      log("could not freeze the page: #{e.message.to_s.first(120)}")
    end

    # Up to five seconds for the web fonts, so text does not reflow between the files.
    def wait_for_fonts(page)
      20.times do
        return if page.evaluate("document.fonts.status") == "loaded"

        self.class.sleep_for(SCROLL_PAUSE)
      end
      log("fonts were still loading after 5 seconds; continuing")
    rescue Ferrum::Error => e
      log("could not wait for fonts: #{e.message.to_s.first(120)}")
    end

    def wait_for_idle(page, reason)
      page.network.wait_for_idle(timeout: IDLE_TIMEOUT)
    rescue Ferrum::TimeoutError
      log("#{reason} for #{IDLE_TIMEOUT} seconds; capturing as is")
    end

    def with_browser
      browser = self.class.new_browser
      yield browser
    ensure
      browser&.quit
      log("browser closed (#{elapsed}s)") if @started
    end

    # The tests swap this out too, so the walk takes no time there.
    def self.sleep_for(seconds) = sleep(seconds)

    # The tests swap this for a fake browser (stub_method), so no test starts Chromium.
    def self.new_browser
      Ferrum::Browser.new(
        headless: true,
        timeout: LOAD_TIMEOUT,
        process_timeout: 30,
        window_size: VIEWPORT,
        browser_path: ENV["BROWSER_PATH"].presence,
        # SwiftShader draws WebGL in software, so a canvas site renders without a GPU. With
        # disable-gpu instead, WebGL is off and such a page captures as a blank gradient.
        browser_options: {
          "no-sandbox" => nil, "disable-dev-shm-usage" => nil, "hide-scrollbars" => nil,
          "use-angle" => "swiftshader", "enable-unsafe-swiftshader" => nil
        }
      )
    end
  end
end
