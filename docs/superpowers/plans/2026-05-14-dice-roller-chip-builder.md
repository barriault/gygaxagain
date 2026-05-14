# Dice roller chip builder: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the dice roller's preset chips with a state-driven formula builder. Each chip mutates an in-memory Stimulus state object (`die`, `count`, `modifier`, `keep`, `mode`) that re-renders the expression field. The Roll button stays the only submit path. The server-side dice parser and form POST contract are unchanged.

**Architecture:** All builder state lives in the rewritten `dice_form_controller.js` (no `static values`, no server roundtrips per chip). The `Play::Dice::FormComponent` exposes two new readers (`die_chips`, `modifier_chips`) that the template iterates to render two rows of `<button type="button">` elements with `data-action` / `data-*-param` / `data-dice-form-target` attributes. A single private `#render()` method in the controller is the only place that touches the DOM after a state mutation. Direct typing into the expression field detaches the builder (state resets, chip highlights clear) so the user can always escape to manual entry. `turbo:submit-end` resets state after a successful Roll.

**Tech Stack:** Rails 8.1 · ViewComponent · Stimulus · Turbo · Tailwind CSS · Lookbook · RSpec · Capybara + `selenium-webdriver` · factory_bot.

**Spec:** [`docs/superpowers/specs/2026-05-14-dice-roller-chip-builder-design.md`](../specs/2026-05-14-dice-roller-chip-builder-design.md).

---

## File structure

**Component (Tasks 1-2):**
- `app/components/play/dice/form_component.rb` — modified (replace `QUICK_CHIPS` with `DIE_CHIPS` + `MODIFIER_CHIPS`)
- `app/components/play/dice/form_component.html.erb` — modified (render two rows of chips with full Stimulus wiring)
- `spec/components/play/dice/form_component_spec.rb` — modified (new chip-list assertion + data-action assertions)

**Stimulus controller (Tasks 3-13):**
- `app/javascript/controllers/dice_form_controller.js` — rewritten (state machine + render)
- `spec/system/phase_7_play_mechanics_spec.rb` — modified (new `describe "dice builder chips"` block with eleven JS examples)

**Lookbook (Task 14):**
- `spec/components/previews/play/dice/form_component_preview.rb` — modified (drop the obsolete `with_sticky_value` snapshot; previews stay otherwise unchanged because Lookbook can't drive Stimulus interactively)

---

## Conventions used in this plan

- Test commands invoke RSpec with the full file path. The repo uses `bundle exec rspec`; if your shell aliases `rspec`, use that.
- System specs (`type: :system, js: true`) launch Chrome via Selenium. They take a few seconds each. Run only the example you're working on during the inner loop: `bundle exec rspec spec/system/phase_7_play_mechanics_spec.rb -e "builds 2d6+3"`.
- "Run, expect FAIL" means run the test and verify it fails for the reason you expect (not a syntax error, not a missing factory). If it fails for a different reason, fix that before moving on.
- Use `git -c commit.gpgsign=false commit` if your local config has GPG signing enabled and you don't want to enter your passphrase for every commit.

---

## Task 1: Update the component spec for the new chip inventory

**Files:**
- Modify: `spec/components/play/dice/form_component_spec.rb`

- [ ] **Step 1: Replace the chip-presence example**

In `spec/components/play/dice/form_component_spec.rb`, find the `it "renders the four quick-roll chips"` example (around line 24). Replace it with the two examples below.

Old:
```ruby
  it "renders the four quick-roll chips" do
    render_inline(described_class.new(scene: scene))

    %w[d20 d100 2d6 adv dis].each do |chip|
      expect(page).to have_button(chip)
    end
  end
```

New:
```ruby
  it "renders the seven die chips" do
    render_inline(described_class.new(scene: scene))

    %w[d4 d6 d8 d10 d12 d20 d100].each do |die|
      expect(page).to have_button(die)
    end
  end

  it "renders the six modifier chips" do
    render_inline(described_class.new(scene: scene))

    [ "+", "−", "keep", "adv", "dis", "clear" ].each do |label|
      expect(page).to have_button(label)
    end
  end

  it "wires die chips to the pickDie Stimulus action with a die param" do
    render_inline(described_class.new(scene: scene))

    chip = page.find_button("d6")
    expect(chip["data-action"]).to include("click->dice-form#pickDie")
    expect(chip["data-dice-form-die-param"]).to eq("d6")
    expect(chip["data-dice-form-target"]).to include("dieChip")
  end

  it "wires the + and − chips to bumpModifier with a delta param" do
    render_inline(described_class.new(scene: scene))

    plus = page.find_button("+")
    expect(plus["data-action"]).to include("click->dice-form#bumpModifier")
    expect(plus["data-dice-form-delta-param"]).to eq("1")

    minus = page.find_button("−")
    expect(minus["data-action"]).to include("click->dice-form#bumpModifier")
    expect(minus["data-dice-form-delta-param"]).to eq("-1")
  end

  it "wires the keep chip to bumpKeep" do
    render_inline(described_class.new(scene: scene))

    keep = page.find_button("keep")
    expect(keep["data-action"]).to include("click->dice-form#bumpKeep")
    expect(keep["data-dice-form-target"]).to include("keepChip")
  end

  it "wires the adv and dis chips to setMode with a mode param" do
    render_inline(described_class.new(scene: scene))

    adv = page.find_button("adv")
    expect(adv["data-action"]).to include("click->dice-form#setMode")
    expect(adv["data-dice-form-mode-param"]).to eq("adv")

    dis = page.find_button("dis")
    expect(dis["data-action"]).to include("click->dice-form#setMode")
    expect(dis["data-dice-form-mode-param"]).to eq("dis")
  end

  it "wires the clear chip to clearAll" do
    render_inline(described_class.new(scene: scene))

    clear = page.find_button("clear")
    expect(clear["data-action"]).to include("click->dice-form#clearAll")
  end

  it "wires the expression field to dice-form#expressionInput for detach detection" do
    render_inline(described_class.new(scene: scene))

    field = page.find_field("dice_roll[expression]")
    expect(field["data-action"]).to include("input->dice-form#expressionInput")
  end
```

- [ ] **Step 2: Run to verify failures**

Run:
```
bundle exec rspec spec/components/play/dice/form_component_spec.rb
```

Expected: the seven new examples fail (the component still renders the old chips and has no `data-action` other than `useChip`). The other examples in the file (`renders an expression input`, `posts to the dice_rolls#create route`, error rendering, asymmetry) still pass.

- [ ] **Step 3: Commit the failing tests**

```bash
git add spec/components/play/dice/form_component_spec.rb
git -c commit.gpgsign=false commit -m "Update dice form component spec for builder chips"
```

---

## Task 2: Render the new chip inventory in the component

**Files:**
- Modify: `app/components/play/dice/form_component.rb`
- Modify: `app/components/play/dice/form_component.html.erb`

- [ ] **Step 1: Replace QUICK_CHIPS with the new chip definitions**

Open `app/components/play/dice/form_component.rb` and replace its body with:

```ruby
module Play
  module Dice
    class FormComponent < ViewComponent::Base
      DIE_CHIPS = %w[d4 d6 d8 d10 d12 d20 d100].freeze

      MODIFIER_CHIPS = [
        { key: "plus",  label: "+",     action: "bumpModifier", params: { delta: 1 } },
        { key: "minus", label: "−",     action: "bumpModifier", params: { delta: -1 } },
        { key: "keep",  label: "keep",  action: "bumpKeep",     params: {} },
        { key: "adv",   label: "adv",   action: "setMode",      params: { mode: "adv" } },
        { key: "dis",   label: "dis",   action: "setMode",      params: { mode: "dis" } },
        { key: "clear", label: "clear", action: "clearAll",     params: {} }
      ].freeze

      def initialize(scene:, expression: nil, error: nil)
        @scene = scene
        @expression = expression
        @error = error
      end

      attr_reader :scene, :expression, :error

      def campaign
        scene.campaign
      end

      def container_dom_id
        helpers.dom_id(scene, :dice_form)
      end

      def die_chips
        DIE_CHIPS
      end

      def modifier_chips
        MODIFIER_CHIPS
      end
    end
  end
end
```

- [ ] **Step 2: Update the template to render the new layout**

Replace `app/components/play/dice/form_component.html.erb` with:

```erb
<div id="<%= container_dom_id %>"
     class="rounded-lg border border-slate-800 bg-slate-900/40 p-4">
  <%= form_with url: helpers.campaign_scene_dice_rolls_path(campaign, scene),
                scope: :dice_roll,
                method: :post,
                local: false,
                html: { "data-controller": "dice-form" } do |f| %>
    <p class="text-xs uppercase tracking-widest text-amber-400">Roll dice</p>

    <div class="mt-3 flex gap-2">
      <%= f.text_field :expression,
                       value: expression,
                       placeholder: "e.g. 1d20+5",
                       autocomplete: "off",
                       "data-dice-form-target": "expression",
                       "data-action": "input->dice-form#expressionInput",
                       class: "flex-1 rounded bg-slate-800 px-3 py-2 text-slate-100 placeholder:text-slate-500 focus:outline-none focus:ring-1 focus:ring-amber-400" %>
      <button type="submit"
              class="rounded bg-amber-500 px-4 py-2 font-semibold text-slate-900 hover:bg-amber-400">Roll</button>
    </div>

    <% if error.present? %>
      <p class="mt-2 text-xs text-rose-400"><%= error %></p>
    <% end %>

    <div class="mt-3 flex flex-wrap gap-2" data-dice-form-target="dieRow">
      <% die_chips.each do |die| %>
        <button type="button"
                data-action="click->dice-form#pickDie"
                data-dice-form-die-param="<%= die %>"
                data-dice-form-target="dieChip"
                data-die="<%= die %>"
                class="rounded bg-slate-800 px-2 py-1 text-xs text-slate-300 hover:bg-slate-700">
          <span data-dice-form-target="dieLabel"><%= die %></span><span class="ml-1 text-amber-300" data-dice-form-target="dieCountBadge"></span>
        </button>
      <% end %>
    </div>

    <div class="mt-2 flex flex-wrap gap-2">
      <% modifier_chips.each do |chip| %>
        <button type="button"
                data-action="click->dice-form#<%= chip[:action] %>"
                <% chip[:params].each do |param_key, param_value| %>
                  data-dice-form-<%= param_key %>-param="<%= param_value %>"
                <% end %>
                data-dice-form-target="<%= chip[:key] %>Chip"
                class="rounded bg-slate-800 px-2 py-1 text-xs text-slate-300 hover:bg-slate-700">
          <span><%= chip[:label] %></span><span class="ml-1 text-amber-300" data-dice-form-target="<%= chip[:key] %>Badge"></span>
        </button>
      <% end %>
    </div>
  <% end %>
</div>
```

- [ ] **Step 3: Run the component spec**

Run:
```
bundle exec rspec spec/components/play/dice/form_component.rb spec/components/play/dice/form_component_spec.rb
```

(The first path is a typo guard — it'll error if you mistype. The real spec file is the second.)

Run:
```
bundle exec rspec spec/components/play/dice/form_component_spec.rb
```

Expected: all examples pass.

- [ ] **Step 4: Commit**

```bash
git add app/components/play/dice/form_component.rb app/components/play/dice/form_component.html.erb
git -c commit.gpgsign=false commit -m "Render builder chip inventory in dice form component"
```

---

## Task 3: System spec — build "2d6+3" without auto-submit

**Files:**
- Modify: `spec/system/phase_7_play_mechanics_spec.rb`

- [ ] **Step 1: Append a new `describe` block at the end of the file**

In `spec/system/phase_7_play_mechanics_spec.rb`, add this `describe` block inside the top-level `RSpec.describe`, immediately before the final `end`:

```ruby
  describe "dice builder chips" do
    before do
      Capybara.app_host = "http://lvh.me"
      sign_in user
      visit play_campaign_scene_path(campaign, scene)
    end

    it "builds 2d6+3 by tapping d6 twice and + three times, without submitting" do
      click_button "d6"
      click_button "d6"
      click_button "+"
      click_button "+"
      click_button "+"

      expect(page).to have_field("dice_roll[expression]", with: "2d6+3")
      # No event card appended — the dice scene log placeholder is still visible.
      expect(page).to have_text(/the scene is set/i)
    end
  end
```

- [ ] **Step 2: Run and verify failure**

Run:
```
bundle exec rspec spec/system/phase_7_play_mechanics_spec.rb -e "builds 2d6+3"
```

Expected: FAIL. The current `dice_form_controller.js` has only `useChip`, so `click->dice-form#pickDie` is a no-op. The field stays empty.

- [ ] **Step 3: Commit the failing test**

```bash
git add spec/system/phase_7_play_mechanics_spec.rb
git -c commit.gpgsign=false commit -m "Add failing system spec: build 2d6+3 from chips"
```

---

## Task 4: Rewrite the Stimulus controller (state, pickDie, bumpModifier, render)

**Files:**
- Modify (rewrite): `app/javascript/controllers/dice_form_controller.js`

- [ ] **Step 1: Replace the controller file**

Replace the entire contents of `app/javascript/controllers/dice_form_controller.js` with:

```js
import { Controller } from "@hotwired/stimulus"

const DICE = ["d4", "d6", "d8", "d10", "d12", "d20", "d100"]

export default class extends Controller {
  static targets = [
    "expression",
    "dieChip", "dieCountBadge",
    "plusChip", "plusBadge",
    "minusChip", "minusBadge",
    "keepChip", "keepBadge",
    "advChip", "disChip",
    "clearChip"
  ]

  connect() {
    this.state = this.#initialState()
    this.preserved = { count: 0, keep: 0 }
    this.programmaticWrite = false
    this.#render()
  }

  pickDie({ params: { die } }) {
    if (!DICE.includes(die)) return
    if (this.state.die && this.state.die !== die) return  // disabled chip
    this.state.die = die
    this.state.count = (this.state.count || 0) + 1
    this.#render()
  }

  bumpModifier({ params: { delta } }) {
    if (!this.state.die) return
    this.state.modifier += Number(delta)
    this.#render()
  }

  #initialState() {
    return { die: null, count: 0, modifier: 0, keep: 0, mode: "normal" }
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
    if (mode === "adv") return `2${die}kh1${this.#modifierStr(modifier)}`
    if (mode === "dis") return `2${die}kl1${this.#modifierStr(modifier)}`
    if (count === 0) return ""
    const keepStr = this.state.keep > 0 ? `kh${this.state.keep}` : ""
    return `${count}${die}${keepStr}${this.#modifierStr(modifier)}`
  }

  #modifierStr(modifier) {
    if (modifier > 0) return `+${modifier}`
    if (modifier < 0) return `${modifier}`
    return ""
  }

  #renderDieChips() {
    const activeClasses = ["bg-amber-500/20", "ring-1", "ring-amber-400", "text-amber-200"]
    const idleClasses = ["bg-slate-800", "text-slate-300"]
    const disabledClasses = ["opacity-50", "cursor-not-allowed"]

    this.dieChipTargets.forEach((chip) => {
      const die = chip.dataset.die
      const isActive = this.state.die === die
      const isDisabled = this.state.die !== null && !isActive

      chip.classList.remove(...activeClasses, ...idleClasses, ...disabledClasses)
      chip.classList.add(...(isActive ? activeClasses : idleClasses))
      if (isDisabled) chip.classList.add(...disabledClasses)
      chip.setAttribute("aria-disabled", isDisabled ? "true" : "false")
      chip.setAttribute("aria-pressed", isActive ? "true" : "false")
    })

    this.dieCountBadgeTargets.forEach((badge) => {
      const chip = badge.closest("button[data-die]")
      const die = chip && chip.dataset.die
      badge.textContent = (this.state.die === die && this.state.count > 1) ? this.state.count : ""
    })
  }

  #renderModifierChips() {
    const { die, modifier, keep, mode } = this.state
    const hasDie = die !== null
    const isMode = mode !== "normal"

    this.plusBadgeTarget.textContent = modifier > 0 ? `+${modifier}` : ""
    this.minusBadgeTarget.textContent = modifier < 0 ? `${Math.abs(modifier)}` : ""
    this.keepBadgeTarget.textContent = keep > 0 ? `${keep}` : ""

    this.#toggleDisabled(this.plusChipTarget, !hasDie)
    this.#toggleDisabled(this.minusChipTarget, !hasDie)
    this.#toggleDisabled(this.keepChipTarget, !hasDie || isMode)

    this.#toggleHighlight(this.keepChipTarget, keep > 0)
    this.#toggleHighlight(this.advChipTarget, mode === "adv")
    this.#toggleHighlight(this.disChipTarget, mode === "dis")
  }

  #toggleDisabled(el, disabled) {
    el.setAttribute("aria-disabled", disabled ? "true" : "false")
    el.classList.toggle("opacity-50", disabled)
    el.classList.toggle("cursor-not-allowed", disabled)
  }

  #toggleHighlight(el, active) {
    const activeClasses = ["bg-amber-500/20", "ring-1", "ring-amber-400", "text-amber-200"]
    activeClasses.forEach((cls) => el.classList.toggle(cls, active))
    el.setAttribute("aria-pressed", active ? "true" : "false")
  }
}
```

This is the skeleton. Subsequent tasks add `bumpKeep`, `setMode`, `clearAll`, `expressionInput`, and the submit-end reset. The full `#renderModifierChips` already routes every chip's visual state by reading `this.state`, so later tasks only add action handlers — they don't need to touch the render method.

- [ ] **Step 2: Run the system spec**

Run:
```
bundle exec rspec spec/system/phase_7_play_mechanics_spec.rb -e "builds 2d6+3"
```

Expected: PASS. (If you get a target-not-found error like "Missing target element 'keepBadge'", that's because `#renderModifierChips` references only `plusBadgeTarget` and `minusBadgeTarget` — keep/adv/dis/clear badges aren't touched yet. The component template renders all of them, so the targets exist. If a target genuinely is missing, double-check Task 2's template.)

Run the whole component spec too, to make sure nothing regressed:
```
bundle exec rspec spec/components/play/dice/form_component_spec.rb
```

Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add app/javascript/controllers/dice_form_controller.js
git -c commit.gpgsign=false commit -m "Rewrite dice form controller skeleton: pickDie + bumpModifier"
```

---

## Task 5: System spec + impl — single-die enforcement

**Files:**
- Modify: `spec/system/phase_7_play_mechanics_spec.rb`
- Modify: `app/javascript/controllers/dice_form_controller.js` (only if the test fails — see Step 2)

- [ ] **Step 1: Add the failing test**

In the `describe "dice builder chips"` block, add:

```ruby
    it "disables other die chips once a die is selected" do
      click_button "d6"
      expect(page).to have_field("dice_roll[expression]", with: "1d6")

      d10 = page.find_button("d10")
      expect(d10["aria-disabled"]).to eq("true")

      click_button "d10"  # Capybara fires the click even on aria-disabled buttons.
      expect(page).to have_field("dice_roll[expression]", with: "1d6")
    end
```

- [ ] **Step 2: Run and verify behavior**

Run:
```
bundle exec rspec spec/system/phase_7_play_mechanics_spec.rb -e "disables other"
```

Expected: PASS already, because `pickDie` in Task 4 already returns early when `this.state.die && this.state.die !== die`, and `#renderDieChips` already sets `aria-disabled="true"` on non-active chips.

If it fails (for instance because `aria-disabled` isn't being set on first render), revisit `#renderDieChips` in Task 4 — there's a bug to fix before moving on.

- [ ] **Step 3: Commit**

```bash
git add spec/system/phase_7_play_mechanics_spec.rb
git -c commit.gpgsign=false commit -m "System spec: single-die enforcement"
```

---

## Task 6: System spec + impl — `clear` chip

**Files:**
- Modify: `spec/system/phase_7_play_mechanics_spec.rb`
- Modify: `app/javascript/controllers/dice_form_controller.js`

- [ ] **Step 1: Add the failing test**

In the `describe "dice builder chips"` block:

```ruby
    it "resets state and re-enables dice when clear is tapped" do
      click_button "d6"
      click_button "+"
      expect(page).to have_field("dice_roll[expression]", with: "1d6+1")

      click_button "clear"
      expect(page).to have_field("dice_roll[expression]", with: "")
      expect(page.find_button("d10")["aria-disabled"]).to eq("false")

      click_button "d10"
      expect(page).to have_field("dice_roll[expression]", with: "1d10")
    end
```

- [ ] **Step 2: Run to confirm failure**

Run:
```
bundle exec rspec spec/system/phase_7_play_mechanics_spec.rb -e "resets state"
```

Expected: FAIL — `clearAll` isn't defined yet, so the chip click is a no-op.

- [ ] **Step 3: Add `clearAll` to the controller**

In `app/javascript/controllers/dice_form_controller.js`, add this method below `bumpModifier`:

```js
  clearAll() {
    this.state = this.#initialState()
    this.preserved = { count: 0, keep: 0 }
    this.#render()
  }
```

- [ ] **Step 4: Run to verify**

Run:
```
bundle exec rspec spec/system/phase_7_play_mechanics_spec.rb -e "resets state"
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add spec/system/phase_7_play_mechanics_spec.rb app/javascript/controllers/dice_form_controller.js
git -c commit.gpgsign=false commit -m "Add clearAll action for the dice form builder"
```

---

## Task 7: System spec — modifier algebra across zero

**Files:**
- Modify: `spec/system/phase_7_play_mechanics_spec.rb`

- [ ] **Step 1: Add the test**

In the `describe "dice builder chips"` block:

```ruby
    it "increments and decrements the modifier across zero" do
      click_button "d6"
      click_button "+"
      click_button "+"
      expect(page).to have_field("dice_roll[expression]", with: "1d6+2")

      click_button "−"
      expect(page).to have_field("dice_roll[expression]", with: "1d6+1")

      click_button "−"
      click_button "−"
      expect(page).to have_field("dice_roll[expression]", with: "1d6-1")
    end
```

- [ ] **Step 2: Run to verify**

Run:
```
bundle exec rspec spec/system/phase_7_play_mechanics_spec.rb -e "modifier across zero"
```

Expected: PASS. `bumpModifier({ params: { delta } })` from Task 4 already handles both signs and `#modifierStr` already omits a zero modifier.

- [ ] **Step 3: Commit**

```bash
git add spec/system/phase_7_play_mechanics_spec.rb
git -c commit.gpgsign=false commit -m "System spec: modifier algebra across zero"
```

---

## Task 8: System spec + impl — `keep` chip with wrap

**Files:**
- Modify: `spec/system/phase_7_play_mechanics_spec.rb`
- Modify: `app/javascript/controllers/dice_form_controller.js`

- [ ] **Step 1: Add the failing test**

```ruby
    it "increments keep up to count and wraps to zero on the next tap" do
      click_button "d20"
      click_button "d20"
      click_button "d20"
      click_button "d20"
      expect(page).to have_field("dice_roll[expression]", with: "4d20")

      click_button "keep"
      click_button "keep"
      expect(page).to have_field("dice_roll[expression]", with: "4d20kh2")

      click_button "keep"
      click_button "keep"  # keep is now equal to count (4)
      expect(page).to have_field("dice_roll[expression]", with: "4d20kh4")

      click_button "keep"  # wraps to 0
      expect(page).to have_field("dice_roll[expression]", with: "4d20")
    end
```

- [ ] **Step 2: Run to confirm failure**

Run:
```
bundle exec rspec spec/system/phase_7_play_mechanics_spec.rb -e "increments keep"
```

Expected: FAIL — `bumpKeep` is undefined.

- [ ] **Step 3: Implement `bumpKeep`**

In `app/javascript/controllers/dice_form_controller.js`, add `bumpKeep` below `bumpModifier`:

```js
  bumpKeep() {
    if (!this.state.die) return
    if (this.state.mode !== "normal") return
    const limit = this.state.count + 1  // wrap inclusive of count, exclusive of count+1
    this.state.keep = (this.state.keep + 1) % limit
    this.#render()
  }
```

`#renderModifierChips` from Task 4 already routes `keep` to its badge and highlight, so no other change is needed.

- [ ] **Step 4: Run to verify**

Run:
```
bundle exec rspec spec/system/phase_7_play_mechanics_spec.rb -e "increments keep"
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add spec/system/phase_7_play_mechanics_spec.rb app/javascript/controllers/dice_form_controller.js
git -c commit.gpgsign=false commit -m "Add bumpKeep action with wrap-to-zero behavior"
```

---

## Task 9: System spec + impl — `adv` and `dis` default to d20

**Files:**
- Modify: `spec/system/phase_7_play_mechanics_spec.rb`
- Modify: `app/javascript/controllers/dice_form_controller.js`

- [ ] **Step 1: Add the failing test**

```ruby
    it "uses d20 as the default die when adv or dis is tapped first" do
      click_button "adv"
      expect(page).to have_field("dice_roll[expression]", with: "2d20kh1")

      click_button "clear"
      click_button "dis"
      expect(page).to have_field("dice_roll[expression]", with: "2d20kl1")
    end

    it "swaps between adv and dis (radio behavior)" do
      click_button "adv"
      expect(page).to have_field("dice_roll[expression]", with: "2d20kh1")

      click_button "dis"
      expect(page).to have_field("dice_roll[expression]", with: "2d20kl1")
    end
```

- [ ] **Step 2: Run to confirm failure**

Run:
```
bundle exec rspec spec/system/phase_7_play_mechanics_spec.rb -e "default die"
```

Expected: FAIL — `setMode` undefined.

- [ ] **Step 3: Implement `setMode`**

In `app/javascript/controllers/dice_form_controller.js`, add `setMode` below `bumpKeep`:

```js
  setMode({ params: { mode } }) {
    if (mode !== "adv" && mode !== "dis") return

    // Toggle off if the same mode is tapped again.
    if (this.state.mode === mode) {
      this.state.mode = "normal"
      this.state.count = this.preserved.count > 0 ? this.preserved.count : 1
      this.state.keep = this.preserved.keep
      this.#render()
      return
    }

    // Entering adv/dis (or swapping). Preserve count/keep only on first entry.
    if (this.state.mode === "normal") {
      this.preserved = { count: this.state.count, keep: this.state.keep }
    }
    if (!this.state.die) this.state.die = "d20"
    this.state.mode = mode
    this.#render()
  }
```

- [ ] **Step 4: Run both new examples**

Run:
```
bundle exec rspec spec/system/phase_7_play_mechanics_spec.rb -e "default die" \
  spec/system/phase_7_play_mechanics_spec.rb -e "swaps between adv and dis"
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add spec/system/phase_7_play_mechanics_spec.rb app/javascript/controllers/dice_form_controller.js
git -c commit.gpgsign=false commit -m "Add setMode action: adv/dis with d20 default and radio swap"
```

---

## Task 10: System spec — adv/dis preserves count/keep and toggles back

**Files:**
- Modify: `spec/system/phase_7_play_mechanics_spec.rb`

- [ ] **Step 1: Add the test**

```ruby
    it "preserves count and keep when entering adv, and restores them when exiting" do
      click_button "d6"
      click_button "d6"
      click_button "d6"
      click_button "+"
      click_button "+"
      expect(page).to have_field("dice_roll[expression]", with: "3d6+2")

      click_button "adv"
      expect(page).to have_field("dice_roll[expression]", with: "2d6kh1+2")

      click_button "adv"  # toggle off
      expect(page).to have_field("dice_roll[expression]", with: "3d6+2")
    end
```

- [ ] **Step 2: Run to verify**

Run:
```
bundle exec rspec spec/system/phase_7_play_mechanics_spec.rb -e "preserves count and keep"
```

Expected: PASS — the preservation logic in Task 9 handles this case.

- [ ] **Step 3: Commit**

```bash
git add spec/system/phase_7_play_mechanics_spec.rb
git -c commit.gpgsign=false commit -m "System spec: adv preserves and restores count/keep"
```

---

## Task 11: System spec + impl — tapping the selected die exits adv/dis

**Files:**
- Modify: `spec/system/phase_7_play_mechanics_spec.rb`
- Modify: `app/javascript/controllers/dice_form_controller.js`

- [ ] **Step 1: Add the failing test**

```ruby
    it "exits adv mode when the selected die is tapped" do
      click_button "d6"
      click_button "d6"
      click_button "+"
      click_button "adv"
      expect(page).to have_field("dice_roll[expression]", with: "2d6kh1+1")

      click_button "d6"  # the active die exits adv, restoring count/keep
      expect(page).to have_field("dice_roll[expression]", with: "2d6+1")
    end
```

- [ ] **Step 2: Run to confirm failure**

Run:
```
bundle exec rspec spec/system/phase_7_play_mechanics_spec.rb -e "exits adv"
```

Expected: FAIL. `pickDie` currently increments count when the same die is tapped, regardless of mode — so tapping d6 while in adv would set `count = 3` (then exit?) or stay in adv. With the existing code in Task 4, `pickDie` just increments count to 3, doesn't change mode, and the field becomes `2d6kh1+1` (unchanged — adv ignores count). Test fails because the field should become `2d6+1`.

- [ ] **Step 3: Update `pickDie` to handle the in-mode case**

Replace the `pickDie` method in `app/javascript/controllers/dice_form_controller.js` with:

```js
  pickDie({ params: { die } }) {
    if (!DICE.includes(die)) return
    if (this.state.die && this.state.die !== die) return  // disabled chip

    // Same die tapped while in adv/dis: exit mode, restore preserved count/keep.
    if (this.state.die === die && this.state.mode !== "normal") {
      this.state.mode = "normal"
      this.state.count = this.preserved.count > 0 ? this.preserved.count : 1
      this.state.keep = this.preserved.keep
      this.#render()
      return
    }

    this.state.die = die
    this.state.count = (this.state.count || 0) + 1
    this.#render()
  }
```

- [ ] **Step 4: Run to verify**

Run:
```
bundle exec rspec spec/system/phase_7_play_mechanics_spec.rb -e "exits adv"
```

Expected: PASS.

Also run the previous adv tests to make sure nothing regressed:
```
bundle exec rspec spec/system/phase_7_play_mechanics_spec.rb -e "preserves count" \
  spec/system/phase_7_play_mechanics_spec.rb -e "default die" \
  spec/system/phase_7_play_mechanics_spec.rb -e "swaps between"
```

Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add spec/system/phase_7_play_mechanics_spec.rb app/javascript/controllers/dice_form_controller.js
git -c commit.gpgsign=false commit -m "Tapping selected die exits adv/dis and restores state"
```

---

## Task 12: System spec + impl — direct typing detaches the builder

**Files:**
- Modify: `spec/system/phase_7_play_mechanics_spec.rb`
- Modify: `app/javascript/controllers/dice_form_controller.js`

- [ ] **Step 1: Add the failing test**

```ruby
    it "clears builder state when the user types directly, then a chip replaces the text" do
      click_button "d6"
      expect(page).to have_field("dice_roll[expression]", with: "1d6")

      fill_in "dice_roll[expression]", with: "1d4+wat"
      expect(page.find_button("d10")["aria-disabled"]).to eq("false")  # builder detached

      click_button "d6"
      expect(page).to have_field("dice_roll[expression]", with: "1d6")
    end
```

- [ ] **Step 2: Run to confirm failure**

Run:
```
bundle exec rspec spec/system/phase_7_play_mechanics_spec.rb -e "clears builder state when the user types"
```

Expected: FAIL — `expressionInput` is undefined, so direct typing doesn't clear state. After `fill_in`, the d6 chip is still active and d10 is still aria-disabled.

- [ ] **Step 3: Implement `expressionInput`**

In `app/javascript/controllers/dice_form_controller.js`, add `expressionInput` below `clearAll`:

```js
  expressionInput(_event) {
    if (this.programmaticWrite) return
    this.state = this.#initialState()
    this.preserved = { count: 0, keep: 0 }
    // Don't touch expressionTarget.value — let the user's typing stand.
    this.#renderDieChips()
    this.#renderModifierChips()
  }
```

- [ ] **Step 4: Run to verify**

Run:
```
bundle exec rspec spec/system/phase_7_play_mechanics_spec.rb -e "clears builder state when the user types"
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add spec/system/phase_7_play_mechanics_spec.rb app/javascript/controllers/dice_form_controller.js
git -c commit.gpgsign=false commit -m "Detach dice builder on direct text input"
```

---

## Task 13: System spec + impl — submit resets the builder

**Files:**
- Modify: `spec/system/phase_7_play_mechanics_spec.rb`
- Modify: `app/javascript/controllers/dice_form_controller.js`

- [ ] **Step 1: Add the failing test**

```ruby
    it "resets builder state after a successful Roll submission" do
      Dice::Random.fixed_queue = [ 4 ]
      click_button "d6"
      click_button "+"
      expect(page).to have_field("dice_roll[expression]", with: "1d6+1")

      click_button "Roll"

      # Wait for the new event card to appear in the log.
      expect(page).to have_text("Result: 5")
      # Form is re-rendered empty; chip state is fresh.
      expect(page).to have_field("dice_roll[expression]", with: "")
      expect(page.find_button("d10")["aria-disabled"]).to eq("false")
    end
```

- [ ] **Step 2: Run to confirm failure**

Run:
```
bundle exec rspec spec/system/phase_7_play_mechanics_spec.rb -e "resets builder state after"
```

Expected: FAIL on the `aria-disabled` assertion. The server's Turbo Stream response replaces the form fragment (so the text field is empty), but the new chip buttons start from a fresh `connect()` — actually, let's see: the new form has new chip elements, the controller reconnects, `connect()` initializes state to fresh. So `aria-disabled="false"` on d10 should hold. The test should actually PASS once the rest of the controller is wired.

If the existing roll path returns a Turbo Stream that *replaces* the whole form, the test passes. If it returns a Turbo Stream that *appends* the event but leaves the form intact, the form retains its values until the user clears them — in which case we need the `turbo:submit-end` listener.

Inspect `app/controllers/play/dice_rolls_controller.rb` to confirm the server response shape. (The existing system spec on line 47 asserts the result appears in the log; check how the form is reset.)

Run:
```
bundle exec rspec spec/system/phase_7_play_mechanics_spec.rb -e "resets builder state after"
```

Decide based on the failure mode:
- If the field already empties (server replaces the form), no listener needed; the test should pass once we trigger one render. In that case, jump to Step 4.
- If the field retains its content after Roll, add the listener in Step 3.

- [ ] **Step 3: Add the `turbo:submit-end` listener (only if Step 2 indicated it's needed)**

In `app/javascript/controllers/dice_form_controller.js`, update `connect()` and add `disconnect()`:

```js
  connect() {
    this.state = this.#initialState()
    this.preserved = { count: 0, keep: 0 }
    this.programmaticWrite = false
    this.boundSubmitEnd = this.#onSubmitEnd.bind(this)
    this.element.addEventListener("turbo:submit-end", this.boundSubmitEnd)
    this.#render()
  }

  disconnect() {
    this.element.removeEventListener("turbo:submit-end", this.boundSubmitEnd)
  }

  #onSubmitEnd(event) {
    if (!event.detail || event.detail.success !== true) return
    this.state = this.#initialState()
    this.preserved = { count: 0, keep: 0 }
    this.programmaticWrite = true
    this.expressionTarget.value = ""
    this.programmaticWrite = false
    this.#render()
  }
```

- [ ] **Step 4: Run to verify**

Run:
```
bundle exec rspec spec/system/phase_7_play_mechanics_spec.rb -e "resets builder state after"
```

Expected: PASS.

- [ ] **Step 5: Run the full builder describe block**

Run:
```
bundle exec rspec spec/system/phase_7_play_mechanics_spec.rb
```

Expected: all `dice builder chips` examples pass, and the original phase-7 end-to-end example still passes (it uses `fill_in` + `click_button "Roll"`, which exercises the detach path).

- [ ] **Step 6: Commit**

```bash
git add spec/system/phase_7_play_mechanics_spec.rb app/javascript/controllers/dice_form_controller.js
git -c commit.gpgsign=false commit -m "Reset dice builder after successful Roll submission"
```

---

## Task 14: Lookbook preview cleanup

**Files:**
- Modify: `spec/components/previews/play/dice/form_component_preview.rb`

- [ ] **Step 1: Drop the obsolete sticky-value preview**

The `with_sticky_value` snapshot pre-fills `expression: "4d6kh3"`. That still works (the field accepts any expression), but since chips no longer drive the field through pre-fills, the snapshot misleads on intent. Keep `default` and `with_error`; drop `with_sticky_value`.

Replace `spec/components/previews/play/dice/form_component_preview.rb` with:

```ruby
module Play
  module Dice
    class FormComponentPreview < ViewComponent::Preview
      def default
        scene = preview_scene
        render Play::Dice::FormComponent.new(scene: scene)
      end

      def with_error
        scene = preview_scene
        render Play::Dice::FormComponent.new(
          scene: scene,
          expression: "1d6+wat",
          error: "unparseable at position 4"
        )
      end

      private

      def preview_scene
        campaign = Campaign.new(name: "Preview Campaign", chaos_factor: 5)
        Scene.new(id: 1, title: "Preview Scene", campaign: campaign)
      end
    end
  end
end
```

- [ ] **Step 2: Verify Lookbook still renders the preview**

If Lookbook previews are smoke-tested in the suite, run the relevant spec. Otherwise, start the dev server and load `/rails/lookbook` in a browser; open `Play::Dice::FormComponentPreview` and confirm both `default` and `with_error` render.

- [ ] **Step 3: Commit**

```bash
git add spec/components/previews/play/dice/form_component_preview.rb
git -c commit.gpgsign=false commit -m "Drop obsolete dice form preview snapshot"
```

---

## Final verification

- [ ] **Step 1: Run the full dice form spec suite**

```
bundle exec rspec spec/components/play/dice/form_component_spec.rb spec/system/phase_7_play_mechanics_spec.rb
```

Expected: every example passes.

- [ ] **Step 2: Run the wider suite to catch any incidental regressions**

```
bundle exec rspec
```

Expected: green.

- [ ] **Step 3: Manual smoke check**

Start the dev server, navigate to a campaign's scene page, and click through:
- Tap `d6 d6 + +` → field reads `2d6+2`.
- Tap `adv` → field reads `2d6kh1+2`.
- Tap `Roll` → event appears in log; form empties; chip highlights reset.
- Type `1d100-3` directly → all chip highlights clear; tap `d6` → field replaced with `1d6`.

If everything looks right, the work is complete.

---

## Spec coverage map

| Spec section | Covered by |
|---|---|
| Chip inventory | Tasks 1, 2 |
| State model + formula derivation | Tasks 4, 7, 8, 9, 10 |
| Die chip behavior (normal) | Tasks 3, 4 |
| Die chip behavior (disabled) | Task 5 |
| Die chip behavior (exits adv/dis) | Task 11 |
| `+` / `−` chips | Tasks 4, 7 |
| `keep` chip with wrap | Task 8 |
| `adv` / `dis` chips with d20 default | Task 9 |
| `adv` / `dis` toggle + radio | Tasks 9, 10 |
| `clear` chip | Task 6 |
| Visual states (badges, aria) | Tasks 4, 6, 8 (badge wiring); Task 1 (aria assertions live in system specs) |
| Direct text detach | Task 12 |
| Reset on submit | Task 13 |
| Lookbook previews | Task 14 |
