import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="scene-log-scroll"
//
// Auto-scrolls the page to the bottom when new content is appended to the
// log container, IF the user was already near the bottom. Does NOT yank
// the scroll if they've scrolled up to read older content.
export default class extends Controller {
  static threshold = 120  // pixels from bottom to count as "near bottom"

  connect() {
    this.wasNearBottom = true
    this.scrollListener = () => this.recordScrollPosition()
    this.observer = new MutationObserver(() => this.maybeScroll())

    window.addEventListener("scroll", this.scrollListener, { passive: true })
    this.observer.observe(this.element, { childList: true, subtree: true })
  }

  disconnect() {
    window.removeEventListener("scroll", this.scrollListener)
    this.observer.disconnect()
  }

  recordScrollPosition() {
    const distanceFromBottom = document.documentElement.scrollHeight
                             - window.innerHeight
                             - window.scrollY
    this.wasNearBottom = distanceFromBottom < this.constructor.threshold
  }

  maybeScroll() {
    if (this.wasNearBottom) {
      window.scrollTo({ top: document.documentElement.scrollHeight, behavior: "smooth" })
    }
  }
}
