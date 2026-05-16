import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="chat-composer"
//
// Behaviors:
// - autosize textarea height as the user types
// - submit on Enter (without Shift)
// - newline on Shift+Enter
//
// The form's form_with(...) wraps Turbo by default, so the response handles
// "clear after success" without explicit JS reset.
export default class extends Controller {
  static targets = ["input", "form"]

  connect() {
    if (this.hasInputTarget) {
      this.autosize()
    }
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
      if (this.hasFormTarget) {
        this.formTarget.requestSubmit()
      }
    }
    // Shift+Enter = allow default newline behavior
  }

  handleInput() {
    this.autosize()
  }
}
