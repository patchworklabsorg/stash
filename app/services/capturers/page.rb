module Capturers
  # A rendered web page in headless Chromium, through Ferrum: the MHTML of the page as loaded
  # (original), a full-page PNG (screenshot) and a print PDF (rendition). One browser, one load.
  #
  # The browser runs with no sandbox inside the container (Docker gives the isolation), with a
  # fixed viewport, and with JavaScript on, because most pages are empty without it. It never
  # signs in anywhere and sends no cookies.
  class Page < Base
    VIEWPORT = [ 1440, 900 ].freeze
    LOAD_TIMEOUT = 60
    IDLE_TIMEOUT = 10

    def call
      log("Chromium: loading #{url}")
      with_browser do |browser|
        page = browser.create_page
        page.go_to(url)
        begin
          page.network.wait_for_idle(timeout: IDLE_TIMEOUT)
        rescue Ferrum::TimeoutError
          log("the page kept loading for #{IDLE_TIMEOUT} seconds; capturing as is")
        end
        log("title: #{page.title.to_s.first(200)}")

        page.mhtml(path: path("page.mhtml"))
        page.screenshot(path: path("page.png"), full: true)
        page.pdf(path: path("page.pdf"), format: :A4, print_background: true)
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

    def with_browser
      browser = Ferrum::Browser.new(
        headless: true,
        timeout: LOAD_TIMEOUT,
        process_timeout: 30,
        window_size: VIEWPORT,
        browser_path: ENV["BROWSER_PATH"].presence,
        browser_options: { "no-sandbox" => nil, "disable-gpu" => nil, "disable-dev-shm-usage" => nil, "hide-scrollbars" => nil }
      )
      yield browser
    ensure
      browser&.quit
    end
  end
end
