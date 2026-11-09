import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Reloads the page every `interval` ms while the element is on it. The archive page renders it
// only while captures run, so the first page without it ends the polling: Turbo morphs the new
// page into the old one (the turbo-refresh-method meta), scroll and focus stay where they were,
// and when the element is gone this controller disconnects. The page stays quiet in a hidden
// tab and catches up when the tab is shown again.
export default class extends Controller {
  static values = { interval: { type: Number, default: 5000 } }

  connect() {
    this.onVisibility = () => this.schedule()
    document.addEventListener("visibilitychange", this.onVisibility)
    this.schedule()
  }

  disconnect() {
    document.removeEventListener("visibilitychange", this.onVisibility)
    clearTimeout(this.timer)
  }

  schedule() {
    clearTimeout(this.timer)
    if (document.hidden) return
    this.timer = setTimeout(() => this.refresh(), this.intervalValue)
  }

  refresh() {
    if (document.hidden) return this.schedule()
    Turbo.visit(window.location.href, { action: "replace" })
  }
}
