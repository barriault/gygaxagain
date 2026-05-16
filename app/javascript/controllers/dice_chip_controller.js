import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="dice-chip"
//
// Behaviors:
// - click rolls the dice by POSTing to the dice_rolls endpoint
// - finds campaign_id and scene_id from parent data attributes
// - sends expression, pc_name, and reason as form params
//
// Expected data attributes on button:
// - data-dice-chip-expression-value
// - data-dice-chip-pc-name-value
// - data-dice-chip-reason-value
export default class extends Controller {
  static values = { expression: String, pcName: String, reason: String }

  async roll(event) {
    event.preventDefault()

    // Find the scene context from a parent data-scene-id attribute
    const sceneId = this.element.closest("[data-scene-id]")?.dataset.sceneId
    const campaignId = this.element.closest("[data-campaign-id]")?.dataset.campaignId

    if (!sceneId || !campaignId) {
      console.error("dice_chip_controller: unable to find scene_id or campaign_id in DOM")
      return
    }

    this.element.disabled = true

    try {
      const csrfToken = document.querySelector('meta[name="csrf-token"]').content
      const response = await fetch(`/campaigns/${campaignId}/scenes/${sceneId}/dice_rolls`, {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "X-CSRF-Token": csrfToken,
          "Accept": "text/vnd.turbo-stream.html"
        },
        body: new URLSearchParams({
          "dice_roll[expression]": this.expressionValue,
          "dice_roll[pc_name]": this.pcNameValue,
          "dice_roll[reason]": this.reasonValue
        })
      })

      if (!response.ok) {
        console.error("dice_chip_controller: POST failed", response.status)
      }
    } catch (error) {
      console.error("dice_chip_controller: error", error)
    } finally {
      this.element.disabled = false
    }
  }
}
