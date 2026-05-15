import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="narration-form"
//
// Behaviors:
// - autosize textarea height as the user types
// - submit on Cmd/Ctrl+Enter
//
// The form's form_with(...) wraps Turbo by default, so the response (a
// turbo_stream replace of the entire form) handles "clear after success"
// without explicit JS reset.
export default class extends Controller {
  static targets = ["text"]

  connect() {
    if (this.hasTextTarget) {
      this.autosize()
    }
  }

  autosize() {
    if (!this.hasTextTarget) return
    const ta = this.textTarget
    ta.style.height = "auto"
    ta.style.height = ta.scrollHeight + "px"
  }

  handleKeydown(event) {
    if ((event.metaKey || event.ctrlKey) && event.key === "Enter") {
      event.preventDefault()
      this.element.requestSubmit()
    }
  }
}
