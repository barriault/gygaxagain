import { Controller } from "@hotwired/stimulus"

const DICE = ["d4", "d6", "d8", "d10", "d12", "d20", "d100"]
const ACTIVE_CLASSES = ["bg-amber-500/20", "ring-1", "ring-amber-400", "text-amber-200"]

export default class extends Controller {
  static targets = [
    "expression",
    "dieChip",
    "plusChip", "plusBadge",
    "minusChip", "minusBadge",
    "advChip", "disChip",
    "clearChip"
  ]

  connect() {
    // Submit reset is implicit: the server's turbo_stream.replace swaps the
    // form fragment, so Stimulus reconnects and runs this initializer fresh.
    this.state = this.#initialState()
    this.preserved = { count: 0 }
    this.programmaticWrite = false
    this.#render()
  }

  pickDie({ params: { die } }) {
    if (!DICE.includes(die)) return
    if (this.state.die && this.state.die !== die) return  // disabled chip

    // Same die tapped while in adv/dis: exit mode, restore preserved count.
    if (this.state.die === die && this.state.mode !== "normal") {
      this.state.mode = "normal"
      this.state.count = this.preserved.count > 0 ? this.preserved.count : 1
      this.#render()
      return
    }

    this.state.die = die
    this.state.count = (this.state.count || 0) + 1
    this.#render()
  }

  bumpModifier({ params: { delta } }) {
    if (!this.state.die) return
    this.state.modifier += Number(delta)
    this.#render()
  }

  setMode({ params: { mode } }) {
    if (mode !== "adv" && mode !== "dis") return

    // Toggle off if the same mode is tapped again.
    if (this.state.mode === mode) {
      this.state.mode = "normal"
      this.state.count = this.preserved.count > 0 ? this.preserved.count : 1
      this.#render()
      return
    }

    // Entering adv/dis (or swapping). Preserve count only on first entry.
    if (this.state.mode === "normal") {
      this.preserved = { count: this.state.count }
    }
    if (!this.state.die) this.state.die = "d20"
    this.state.mode = mode
    this.#render()
  }

  clearAll() {
    this.state = this.#initialState()
    this.preserved = { count: 0 }
    this.#render()
  }

  expressionInput(_event) {
    if (this.programmaticWrite) return
    this.state = this.#initialState()
    this.preserved = { count: 0 }
    // Don't touch expressionTarget.value — let the user's typing stand.
    this.#renderDieChips()
    this.#renderModifierChips()
  }

  #initialState() {
    return { die: null, count: 0, modifier: 0, mode: "normal" }
  }

  #render() {
    this.#renderExpression()
    this.#renderDieChips()
    this.#renderModifierChips()
  }

  #renderExpression() {
    this.programmaticWrite = true
    this.expressionTarget.value = this.#formula()
    this.programmaticWrite = false
  }

  #formula() {
    const { die, count, modifier, mode } = this.state
    if (!die) return ""
    if (mode === "adv") return `2${die}dl${this.#modifierStr(modifier)}`
    if (mode === "dis") return `2${die}dh${this.#modifierStr(modifier)}`
    if (count === 0) return ""
    return `${count}${die}${this.#modifierStr(modifier)}`
  }

  #modifierStr(modifier) {
    if (modifier > 0) return `+${modifier}`
    if (modifier < 0) return `${modifier}`
    return ""
  }

  #renderDieChips() {
    const idleClasses = ["bg-slate-800", "text-slate-300"]
    const disabledClasses = ["opacity-50", "cursor-not-allowed"]

    this.dieChipTargets.forEach((chip) => {
      const die = chip.dataset.die
      const isActive = this.state.die === die
      const isDisabled = this.state.die !== null && !isActive

      chip.classList.remove(...ACTIVE_CLASSES, ...idleClasses, ...disabledClasses)
      chip.classList.add(...(isActive ? ACTIVE_CLASSES : idleClasses))
      if (isDisabled) chip.classList.add(...disabledClasses)
      chip.setAttribute("aria-disabled", isDisabled ? "true" : "false")
      chip.setAttribute("aria-pressed", isActive ? "true" : "false")
    })
  }

  #renderModifierChips() {
    const { die, modifier, mode } = this.state
    const hasDie = die !== null

    this.plusBadgeTarget.textContent = modifier > 0 ? `+${modifier}` : ""
    this.minusBadgeTarget.textContent = modifier < 0 ? `${Math.abs(modifier)}` : ""

    this.#toggleDisabled(this.plusChipTarget, !hasDie)
    this.#toggleDisabled(this.minusChipTarget, !hasDie)

    this.#toggleHighlight(this.advChipTarget, mode === "adv")
    this.#toggleHighlight(this.disChipTarget, mode === "dis")
    this.#toggleDisabled(this.clearChipTarget, false)
  }

  #toggleDisabled(el, disabled) {
    el.setAttribute("aria-disabled", disabled ? "true" : "false")
    el.classList.toggle("opacity-50", disabled)
    el.classList.toggle("cursor-not-allowed", disabled)
  }

  #toggleHighlight(el, active) {
    ACTIVE_CLASSES.forEach((cls) => el.classList.toggle(cls, active))
    el.setAttribute("aria-pressed", active ? "true" : "false")
  }
}
