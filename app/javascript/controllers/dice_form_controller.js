import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["expression"]

  useChip(event) {
    const expression = event.params.expression
    if (!expression) return
    this.expressionTarget.value = expression
    this.element.requestSubmit()
  }
}
