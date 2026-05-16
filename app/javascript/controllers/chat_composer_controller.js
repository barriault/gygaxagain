import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="chat-composer"
//
// Behaviors:
// - autosize textarea height as the user types
// - submit on Enter (without Shift)
// - newline on Shift+Enter
// - clear textarea after a successful submit (head :no_content response)
// - scroll the page to the bottom when new turbo-stream content arrives,
//   so streaming narration stays visible without manual scrolling
export default class extends Controller {
  static targets = ["input", "form"]

  connect() {
    if (this.hasInputTarget) this.autosize()

    this._onSubmitEnd = this.handleSubmitEnd.bind(this)
    this._onStreamRender = this.handleStreamRender.bind(this)

    if (this.hasFormTarget) {
      this.formTarget.addEventListener("turbo:submit-end", this._onSubmitEnd)
    }
    document.addEventListener("turbo:before-stream-render", this._onStreamRender)
  }

  disconnect() {
    if (this.hasFormTarget) {
      this.formTarget.removeEventListener("turbo:submit-end", this._onSubmitEnd)
    }
    document.removeEventListener("turbo:before-stream-render", this._onStreamRender)
  }

  autosize() {
    if (!this.hasInputTarget) return
    const ta = this.inputTarget
    ta.style.height = "auto"
    ta.style.height = ta.scrollHeight + "px"
  }

  handleKeydown(event) {
    // Enter without Shift = submit
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      if (this.hasFormTarget) this.formTarget.requestSubmit()
    }
    // Shift+Enter = allow default newline behavior
  }

  handleInput() {
    this.autosize()
  }

  handleSubmitEnd(event) {
    // Only clear if the submit succeeded (controller returned 2xx including 204).
    if (event.detail?.success === false) return
    if (!this.hasInputTarget) return
    this.inputTarget.value = ""
    this.autosize()
  }

  // Whenever a new turbo-stream is about to render anywhere on the page,
  // scroll to the bottom on the next animation frame (after the DOM update).
  handleStreamRender(_event) {
    requestAnimationFrame(() => {
      window.scrollTo({ top: document.body.scrollHeight, behavior: "smooth" })
    })
  }
}
