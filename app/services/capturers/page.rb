require "base64"

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
  # once in viewport steps, returns to the top, and freezes the page. See docs/design.md,
  # "Dynamic pages".
  class Page < Base
    VIEWPORT = [ 1440, 900 ].freeze
    LOAD_TIMEOUT = 60
    IDLE_TIMEOUT = 10
    # The walk down the page: at most this many steps of one viewport each, this long apart.
    SCROLL_STEPS = 60
    SCROLL_PAUSE = 0.25
    # Up to this many quarter seconds for the web fonts.
    FONT_WAITS = 20
    # After the walk, time for the last reveals and the images they started.
    SETTLE = 1.0
    # The tallest screenshot: Chromium blanks or clips captures past 16384px, and a feed that
    # grows on every scroll would otherwise ask for one the size of the walk, or more.
    MAX_SCREENSHOT_HEIGHT = 16_384

    def call
      @started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      attempts = 0
      begin
        attempts += 1
        log("Chromium: loading #{url}#{" (second try)" if attempts > 1}")
        with_browser { |browser| capture_in(browser) }
      rescue Ferrum::Error => e
        # A heavy page can take the browser or its renderer down once. One more try, in a new
        # browser, when there is time for it.
        retry if crashed?(e) && attempts < 2 && elapsed < Capturers.timeout / 2
        raise
      end

      outputs = [
        output("original", "page.mhtml", content_type: "multipart/related"),
        output("screenshot", "page.png", content_type: "image/png"),
        output("rendition", "page.pdf", content_type: "application/pdf")
      ]
      outputs.insert(1, output("view", "page.html", content_type: "text/html")) if ::File.exist?(path("page.html"))
      outputs
    rescue Ferrum::Error => e
      raise ToolFailed, "Chromium: #{e.class}: #{e.message.to_s.first(300)}"
    end

    # One response from the network is kept for the view up to this size, and all of them up
    # to the total. Fonts and images only; the MHTML already carries the HTML and the CSS.
    VIEW_RESOURCE_BYTES = 5.megabytes
    VIEW_RESOURCES_TOTAL = 60.megabytes
    VIEW_TYPES = %r{\A(font/|image/|application/(x-)?font|application/vnd\.ms-fontobject)}

    private

    def capture_in(browser)
      page = browser.create_page
      calm(page)
      page.go_to(url)
      wait_for_idle(page, "the page kept loading")
      log("title: #{page.title.to_s.first(200)} (#{elapsed}s)")

      height = reveal(page)
      wait_for_idle(page, "images kept loading after the scroll")
      self.class.sleep_for(SETTLE)
      freeze(page)

      log("saving the MHTML (#{elapsed}s)")
      page.mhtml(path: path("page.mhtml"))
      log("saving the screenshot (#{elapsed}s)")
      screenshot(page, height)
      log("saving the PDF (#{elapsed}s)")
      page.pdf(path: path("page.pdf"), format: :A4, print_background: true)
      log("saving the view (#{elapsed}s)")
      write_view(page)
      log("done (#{elapsed}s)")
    end

    def elapsed
      (Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started).round(1)
    end

    # The browser process died, or the page's renderer crashed and Ferrum lost the target.
    def crashed?(error)
      return true if error.is_a?(Ferrum::DeadBrowserError) || error.is_a?(Ferrum::NoSuchPageError)

      error.message.to_s.match?(/crashed|Inspected target navigated or closed/i)
    end

    # Before the page loads: ask for reduced motion, so pages that honor it skip their
    # entrance animations, and run the ones that remain at 50x so they are over in time.
    def calm(page)
      page.command("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "reduce" } ])
      page.command("Animation.enable")
      page.command("Animation.setPlaybackRate", playbackRate: 50)
    rescue Ferrum::Error => e
      raise if crashed?(e)

      log("could not set reduced motion: #{e.message.to_s.first(120)}")
    end

    # Walks down the page one viewport at a time, so observers fire and lazy images load,
    # then returns to the top. Waits for fonts first, so text does not reflow in the capture.
    # Returns the height of the page after the walk.
    def reveal(page)
      wait_for_fonts(page)
      height = page.evaluate("document.documentElement.scrollHeight").to_i
      step = VIEWPORT.last
      steps = [ (height.to_f / step).ceil, SCROLL_STEPS ].min
      log("scrolling #{height}px in #{steps} steps")
      steps.times do |i|
        page.execute("window.scrollTo({ top: #{(i + 1) * step}, left: 0, behavior: \"instant\" })")
        self.class.sleep_for(SCROLL_PAUSE)
        if i.zero? && steps > 1 && page.evaluate("window.scrollY").to_i.zero?
          log("the page did not scroll; an inner element scrolls instead, so the walk reveals nothing")
          break
        end
      end
      page.execute("window.scrollTo({ top: 0, left: 0, behavior: \"instant\" })")
      self.class.sleep_for(SCROLL_PAUSE)
      final = page.evaluate("document.documentElement.scrollHeight").to_i
      log("page is #{final}px tall after the scroll")
      final
    rescue Ferrum::Error => e
      raise if crashed?(e)

      log("the scroll stopped early: #{e.message.to_s.first(120)}")
      height || VIEWPORT.last
    end

    # Stops the page from drawing new frames while the files are written: pauses media, takes
    # away requestAnimationFrame in every frame, and pauses the remaining animations, so a
    # render loop (a WebGL scene, a carousel) keeps its last frame. Without this, a
    # software-rendered WebGL scene made one screenshot take 16 minutes, because every frame
    # it kept drawing had to be composited first.
    FREEZE = <<~JS.freeze
      document.querySelectorAll("video, audio").forEach((media) => { try { media.pause(); } catch (_) {} });
      window.requestAnimationFrame = () => 0;
      window.cancelAnimationFrame = () => {};
    JS

    def freeze(page)
      page.frames.each do |frame|
        frame.execute(FREEZE)
      rescue Ferrum::Error => e
        raise if crashed?(e)
      end
      page.command("Animation.setPlaybackRate", playbackRate: 0)
    rescue Ferrum::Error => e
      raise if crashed?(e)

      log("could not freeze the page: #{e.message.to_s.first(120)}")
    end

    # Up to five seconds for the web fonts, so text does not reflow between the files.
    def wait_for_fonts(page)
      FONT_WAITS.times do
        return if page.evaluate("document.fonts.status") == "loaded"

        self.class.sleep_for(SCROLL_PAUSE)
      end
      log("fonts were still loading after #{FONT_WAITS / 4} seconds; continuing")
    rescue Ferrum::Error => e
      raise if crashed?(e)

      log("could not wait for fonts: #{e.message.to_s.first(120)}")
    end

    # Ferrum answers false when the network is still busy at the deadline; it does not raise.
    def wait_for_idle(page, reason)
      return if page.network.wait_for_idle(timeout: IDLE_TIMEOUT)

      log("#{reason} for #{IDLE_TIMEOUT} seconds; capturing as is")
    end

    # The whole page, as tall as the walk found it, up to the cap. Through the protocol rather
    # than Ferrum's `full: true`, which reads the height again and sets no limit.
    def screenshot(page, height)
      clip_height = [ height, SCROLL_STEPS * VIEWPORT.last, MAX_SCREENSHOT_HEIGHT ].min
      clip_height = VIEWPORT.last if clip_height < VIEWPORT.last
      log("the screenshot is cut at #{clip_height}px of #{height}px") if clip_height < height
      result = page.command("Page.captureScreenshot", format: "png", captureBeyondViewport: true,
        clip: { x: 0, y: 0, width: VIEWPORT.first, height: clip_height, scale: 1 })
      ::File.binwrite(path("page.png"), Base64.decode64(result.fetch("data")))
    end

    # The copy a browser can show (Capturers::Mhtml): the MHTML as one HTML file, with the
    # fonts and images Chromium's MHTML leaves out taken from the network traffic of this load,
    # and each <canvas> replaced by what was drawn on it. A view that cannot be made is logged
    # and skipped; the MHTML, PNG and PDF stand on their own.
    def write_view(page)
      html = Mhtml.inline(path("page.mhtml"), resources: view_resources(page), canvases: canvas_images(page))
      ::File.write(path("page.html"), html)
      log("view: #{html.bytesize} bytes as one HTML file")
    rescue Error, Ferrum::Error => e
      log("no view: #{e.message.to_s.first(200)}")
    end

    def view_resources(page)
      total = 0
      page.network.traffic.each_with_object({}) do |exchange, resources|
        response = exchange.response
        next unless response&.status == 200 && response.content_type.to_s.match?(VIEW_TYPES)
        next if resources.key?(response.url)

        body = response.body
        next if body.nil? || body.bytesize > VIEW_RESOURCE_BYTES || (total += body.bytesize) > VIEW_RESOURCES_TOTAL

        resources[response.url] = Mhtml::Part.new(location: response.url, content_type: response.content_type, body: body)
      rescue Ferrum::Error
        next
      end
    end

    # What each canvas shows, as a PNG data URL, in document order; nil where it cannot be read
    # (a tainted canvas, or WebGL without a kept drawing buffer).
    def canvas_images(page)
      Array(page.evaluate(<<~JS))
        Array.from(document.querySelectorAll("canvas")).map((canvas) => {
          try { return canvas.width && canvas.height ? canvas.toDataURL("image/png") : null; } catch (_) { return null; }
        })
      JS
    rescue Ferrum::Error
      []
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
        # enable-unsafe-swiftshader is what turns it on since Chromium 128: the shader compiler
        # is not hardened against hostile shaders, and the container is the boundary.
        browser_options: {
          "no-sandbox" => nil, "disable-dev-shm-usage" => nil, "hide-scrollbars" => nil,
          "use-angle" => "swiftshader", "enable-unsafe-swiftshader" => nil
        }
      )
    end
  end
end
