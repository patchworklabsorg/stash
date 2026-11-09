import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Refreshes the page every `interval` ms while the element is on it, through Turbo's page
// refresh with morphing: the new page is merged into the old one, scroll and focus stay. The
// archive page renders the element only while captures run, so the first page without it ends
// the polling: the morph removes the element and this controller disconnects.
//
// What the refresh must not do: cancel a visit or a form the person started (Turbo.session.refresh
// skips while a visit is current; forms are checked here), wipe what they typed or close a
// <details> they opened (the morph attribute hook below), replace the page with an error page
// when the server hiccups (the fetch response hook), or run in a hidden tab.
export default class extends Controller {
  static values = { interval: { type: Number, default: 5000 } }

  connect() {
    this.onVisibility = () => { if (!document.hidden) this.refresh() }
    this.onMorphAttribute = (event) => this.keepLocalState(event)
    this.onFetchResponse = (event) => this.skipErrorResponse(event)
    document.addEventListener("visibilitychange", this.onVisibility)
    document.addEventListener("turbo:before-morph-attribute", this.onMorphAttribute)
    document.addEventListener("turbo:before-fetch-response", this.onFetchResponse)
    this.schedule()
  }

  disconnect() {
    document.removeEventListener("visibilitychange", this.onVisibility)
    document.removeEventListener("turbo:before-morph-attribute", this.onMorphAttribute)
    document.removeEventListener("turbo:before-fetch-response", this.onFetchResponse)
    clearTimeout(this.timer)
  }

  schedule() {
    clearTimeout(this.timer)
    if (document.hidden) return
    this.timer = setTimeout(() => this.refresh(), this.intervalValue)
  }

  refresh() {
    const busy = document.hidden || Turbo.navigator.currentVisit || Turbo.navigator.formSubmission
    if (!busy) {
      this.refreshing = true
      Turbo.session.refresh(document.baseURI, { method: "morph", scroll: "preserve" })
    }
    // The morph keeps this element, and this controller with it, while captures still run, so
    // the next tick is set here; connect() does not run again. When the new page has no poll
    // element, the morph removes it and disconnect() clears the timer.
    this.schedule()
  }

  // A value the person typed, and a <details> they opened, are theirs, not the server's.
  keepLocalState(event) {
    const { attributeName } = event.detail
    const target = event.target
    const typed = attributeName === "value" && (target instanceof HTMLInputElement || target instanceof HTMLTextAreaElement)
    const opened = attributeName === "open" && target instanceof HTMLDetailsElement
    if (typed || opened) event.preventDefault()
  }

  // A refresh that gets a 502 from a proxy or a 500 from the app must not replace the page with
  // the error page: drop that visit, keep what is shown, and try again at the next tick. The
  // visit has to be stopped as well, or it stays current and blocks every later refresh.
  skipErrorResponse(event) {
    const response = event.detail.fetchResponse
    if (this.refreshing && response && !response.succeeded) {
      event.preventDefault()
      Turbo.navigator.stop()
    }
    this.refreshing = false
  }
}
