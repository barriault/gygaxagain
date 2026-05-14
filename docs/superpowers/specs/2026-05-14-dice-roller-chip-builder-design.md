# Dice roller chip builder

Date: 2026-05-14
Status: Design spec. Drives the writing-plans pass for this change.
Parent: [`2026-05-14-v2-phase-7-dice-and-mythic-oracle-design.md`](2026-05-14-v2-phase-7-dice-and-mythic-oracle-design.md)

## Scope

Replace the dice roller's preset chips with a *formula builder*. Today the chips in [`Play::Dice::FormComponent`](../../../app/components/play/dice/form_component.rb) (`d20`, `d100`, `2d6`, `adv`, `dis`) each stuff a fixed expression into the text field and auto-submit. After this change, chip taps mutate a small builder state that re-renders the expression as the user composes it; the Roll button is the only thing that submits.

Out of scope:
- The server-side dice parser ([`Dice::Parser`](../../../app/services/dice/parser.rb)) and roll service. They already support every expression the builder can produce.
- The Mythic oracle UI and any Phase 7 server logic. Only the dice form component and its Stimulus controller change.

## Goals

- Build any expression of the form `[N]dX [kh|kl K] [± M]` by tapping chips, with no manual typing required for the common cases.
- Keep the text field as the source of truth that gets POSTed. The builder is one way to populate it.
- Make it visually obvious which die is "active", how many of it are queued, what the modifier is, and whether `adv`/`dis`/`keep` are engaged.
- Preserve the existing form contract (POST shape, error rendering, asymmetry guarantees, Turbo behavior).

## Non-goals

- Touch-and-hold gestures, drag interactions, animated transitions. Tap-only.
- Persisting builder state across reloads. State is in-memory in the Stimulus controller.
- A "history of recent rolls" picker. Out of scope.

## Chip inventory

Two rows of chips, in this order:

| Row | Chips |
|-----|-------|
| Dice | `d4` `d6` `d8` `d10` `d12` `d20` `d100` |
| Modifiers | `+` `−` `keep` `adv` `dis` `clear` |

The previous chips (`d20`, `d100`, `2d6`, `adv`, `dis`) are gone as presets. `d20`, `d100`, `adv`, and `dis` reappear in the new role; `2d6` does not (the user gets `2d6` by tapping `d6` twice).

## Builder state model

The Stimulus controller owns a single state object:

```js
{
  die:      null | "d4" | "d6" | "d8" | "d10" | "d12" | "d20" | "d100",
  count:    integer >= 0,
  modifier: integer,            // signed; can be negative
  keep:     integer >= 0,       // 0 means "no keep clause"
  mode:     "normal" | "adv" | "dis"
}
```

Initial state: `{ die: null, count: 0, modifier: 0, keep: 0, mode: "normal" }`.

### Formula derivation (state → text)

The text field's value is derived from state on every mutation:

- If `die == null` → empty string.
- If `mode == "adv"` → `2{die}kh1{±mod?}`. `count` and `keep` are ignored.
- If `mode == "dis"` → `2{die}kl1{±mod?}`. `count` and `keep` are ignored.
- If `mode == "normal"`:
  - If `count == 0` → empty string.
  - Otherwise: `{count}{die}` + (`kh{keep}` if `keep > 0`) + modifier.
- Modifier rendering: `+N` if `modifier > 0`, `-N` if `modifier < 0`, omitted if `modifier == 0`.

Examples:

| State | Text |
|-------|------|
| die=d6, count=3, mod=+2 | `3d6+2` |
| die=d6, count=3, mod=+2, keep=1 | `3d6kh1+2` |
| die=d6, count=3, mod=+2, mode=adv | `2d6kh1+2` |
| die=d20, count=0, mod=0, mode=adv | `2d20kh1` |
| die=d20, count=0, mod=−1, mode=dis | `2d20kl1-1` |

Every formula the builder can produce is accepted by [`Dice::Parser`](../../../app/services/dice/parser.rb).

## Chip behaviors

### Die chips (`d4` through `d100`)

- `die == null` → tapping selects that die and sets `count = 1`. Other die chips become disabled.
- `die == this die`, `mode == "normal"` → increment `count` by 1.
- `die == this die`, `mode == "adv" | "dis"` → exit mode (set `mode = "normal"`), restore `count` and `keep` from the preserved slot (count defaults to 1 if it was 0). Modifier preserved.
- `die != this die` → chip is disabled. Tap is a no-op. To switch dice, the user taps `clear`.

### `+` chip

- Disabled when `die == null`.
- Otherwise increment `modifier` by 1.

### `−` chip

- Disabled when `die == null`.
- Otherwise decrement `modifier` by 1. (Modifier can go negative.)

### `keep` chip

- Disabled when `die == null` or `mode != "normal"`.
- Each tap: `keep = (keep + 1) % (count + 1)`. So with `count = 4`: tap → 1, 2, 3, 4, 0 (cleared), 1, ... This gives the user a way to turn keep off without touching `clear`.

### `adv` chip

- Always enabled.
- `mode == "adv"` → return to `mode = "normal"`. Restore the `count` that was active before entering adv (or 1 if it was 0). Keep is restored too.
- Otherwise: if `die == null`, set `die = "d20"`. Save current `count` and `keep` to a "preserved" slot, then set `mode = "adv"`.

### `dis` chip

Same as `adv` but with `mode = "dis"`.

`adv` and `dis` are radio: tapping `dis` while in adv mode replaces adv with dis (the preserved count/keep are not consumed — they remain until the user exits the mode pair).

### `clear` chip

- Always enabled.
- Resets state to initial. Empties the text field.

## Visual states

- **Selected die:** filled background (e.g. `bg-amber-500/20 ring-1 ring-amber-400`), text in amber. A small superscript shows `count` when `count > 1`: `d6 ³`.
- **Disabled die chips** (a different die is selected): `opacity-50 cursor-not-allowed`, `aria-disabled="true"`. Tapping does nothing.
- **`+` / `−` modifier badge:** when `modifier > 0`, the `+` chip shows the value (`+ ³`). When `modifier < 0`, the `−` chip shows the absolute value (`− ²`). When `modifier == 0`, no badge.
- **`keep` badge:** when `keep > 0`, the chip is highlighted and shows the current `keep` value as a small superscript badge (e.g. `keep ²`).
- **`adv` / `dis` active:** highlighted same as selected die. Mutually exclusive visual state.
- **Disabled `+`/`−`/`keep`** (because no die or because mode is adv/dis): `opacity-50 cursor-not-allowed`, `aria-disabled="true"`.

All highlights and badges update in a single `render()` pass after each state mutation. No CSS transitions in this pass.

## Detachment: direct text input

If the text field receives an `input` event that did not originate from the builder (i.e. the user typed), the controller:

1. Clears builder state to initial.
2. Removes all chip highlights / badges (re-runs `render()`).
3. Leaves the text field untouched.

From that point chips remain functional but operate on fresh state. Tapping `d6` after typing manual text **replaces** the typed text with `1d6`. (This is intentional — the alternative, a "dead" chip row, is a footgun.)

Implementation note: the controller distinguishes its own writes from user typing by setting a `programmaticWrite` flag around its assignments to `expressionTarget.value`, then ignoring the `input` event that fires.

## Reset triggers

The builder resets to initial state on:

1. `clear` chip tap.
2. Successful form submission (the controller listens for `turbo:submit-end` and resets if the event's `detail.success` is true). On error the submission re-renders with an error message and the formula stays in the field for correction.

## Implementation surface

### [`app/components/play/dice/form_component.rb`](../../../app/components/play/dice/form_component.rb)

Replace `QUICK_CHIPS` with structured chip definitions. Suggested shape (verbatim values are illustrative; the implementation plan will lock them in):

```ruby
DIE_CHIPS      = %w[d4 d6 d8 d10 d12 d20 d100].freeze
MODIFIER_CHIPS = [
  { key: "plus",  label: "+",     action: "bumpModifier", delta: 1 },
  { key: "minus", label: "−",     action: "bumpModifier", delta: -1 },
  { key: "keep",  label: "keep",  action: "bumpKeep" },
  { key: "adv",   label: "adv",   action: "setMode",      mode: "adv" },
  { key: "dis",   label: "dis",   action: "setMode",      mode: "dis" },
  { key: "clear", label: "clear", action: "clearAll" }
].freeze
```

The component no longer exposes `quick_chips` as a Hash<String,String>. It exposes two readers (`die_chips`, `modifier_chips`) that the template iterates.

### [`app/components/play/dice/form_component.html.erb`](../../../app/components/play/dice/form_component.html.erb)

- Render the dice row and modifier row as two `flex flex-wrap gap-2` divs.
- Each die chip:
  - `data-action="click->dice-form#pickDie"`
  - `data-dice-form-die-param="d6"` (etc.)
  - `data-dice-form-target="dieChip"`
  - `data-die="d6"` so `render()` can find the chip by die.
  - Inner span for the count badge: `data-dice-form-target="dieCountBadge"`.
- Each modifier chip: similar pattern (`data-action`, target, params keyed off the definition).
- The text field gets `data-action="input->dice-form#expressionInput"` for detach detection.

### [`app/javascript/controllers/dice_form_controller.js`](../../../app/javascript/controllers/dice_form_controller.js)

Rewrite. New shape:

```js
static targets = [
  "expression",
  "dieChip", "dieCountBadge",   // multiple, one per die
  "plusChip", "plusBadge",
  "minusChip", "minusBadge",
  "keepChip", "keepBadge",
  "advChip", "disChip",
  "clearChip"
]

connect()                       // reset state, render()

// Actions
pickDie({ params: { die } })
bumpModifier({ params: { delta } })
bumpKeep()
setMode({ params: { mode } })
clearAll()
expressionInput(event)

// Lifecycle
submit-end listener on the form element
```

All state lives in instance fields; no `static values`. A single private `#render()` method handles every DOM update — set `expressionTarget.value` (with the `programmaticWrite` flag), then toggle classes and badge text on every chip target.

The chip-style class lists (active vs. inactive vs. disabled) live as small constants in the controller for readability.

### Specs

**[`spec/components/play/dice/form_component_spec.rb`](../../../spec/components/play/dice/form_component_spec.rb)** — update the "renders the four quick-roll chips" example. New chip list to assert: `%w[d4 d6 d8 d10 d12 d20 d100 + − keep adv dis clear]`. Also assert that each chip has the right `data-action` attribute. The asymmetry guard test stays as-is.

**[`spec/system/phase_7_play_mechanics_spec.rb`](../../../spec/system/phase_7_play_mechanics_spec.rb)** — add a `describe "dice builder chips"` block with these examples (each is a Capybara JS scenario that interacts with chips and asserts the expression field value):

1. `d6 ×2`, `+` ×3 → field is `2d6+3`.
2. Tap `d6`, then `d10` → `d10` is disabled (`aria-disabled="true"`), field stays `1d6`.
3. Tap `d6`, `clear`, `d10` → field is `1d10`, all dice re-enabled.
4. Tap `d6`, `+` ×2, `−` ×1 → field is `1d6+1`.
5. Tap `d20` ×4, `keep` ×2 → field is `4d20kh2`.
6. Tap `d20` ×4, `keep` ×5 (one past `count`) → field is `4d20` (keep wrapped to 0).
7. Tap `adv` from initial state → field is `2d20kh1`.
8. Tap `d6` ×3, `+` ×2, `adv` → `2d6kh1+2`. Tap `adv` again → `3d6+2`.
9. Tap `adv`, then `dis` → `2d20kl1`.
10. Type `1d4+wat` directly into the field → die chip highlights clear. Tap `d6` → field replaced with `1d6`.
11. Build `1d6+1`, submit the Roll button → wait for the event to land in the log → field empties and all chip state resets.

## Acceptance criteria

- The seven die chips and six modifier chips render in the order specified.
- Tapping the chip sequences in spec examples 1–11 produces the documented field values.
- Tapping any die chip does NOT submit the form. Only the Roll button submits.
- The text field still POSTs to `campaign_scene_dice_rolls_path` with the same `dice_roll[expression]` param. Server-side rendering, error handling, and asymmetry are unaffected.
- The component spec's "no secret leakage" example still passes.
- All existing `Play::Dice::FormComponent` spec examples still pass after the chip-list assertion is updated.

## Risks & mitigations

- **Detach surprises the user.** They type "1d", then tap `d6` and expect `1d6` to be appended. Instead they get `1d6` replacing their typing. Mitigation: this is documented behavior; the `clear` chip is one tap away if they want to start over deliberately. Revisit if a real user trips on it.
- **Stimulus state in a controller that may be reconnected by Turbo.** If the form fragment gets replaced by a Turbo Stream after a roll, the controller's `connect()` runs fresh and state resets — which is actually what we want post-submit. If a server-side error re-renders the form, the controller resets but the text field carries the prior expression (server sets the `value`), so the user can edit and resubmit. The builder won't reflect the formula's structure (no parse-back), but tapping any chip will detach correctly.
- **Accessibility.** Disabled chips need `aria-disabled="true"` rather than the `disabled` attribute (they're `<button type="button">` and we want them focusable for screen readers, but inert). Active chips need `aria-pressed="true"`.

## Out of this spec (deferred)

- Parse the text field back into builder state so that manual edits keep the chip UI in sync. Not worth the complexity for the v1 of this feature.
- Long-press to decrement a die count. Tap-only is enough.
- Persisting modifier/keep across rolls ("sticky" state). Each roll starts fresh.
