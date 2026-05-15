# v2 Phase 9 — Asymmetry hardening + first end-to-end playable session

Date: 2026-05-15
Status: Design spec. Drives the writing-plans pass.
Parent roadmap: [`2026-05-13-v2-phase-0-roadmap-design.md`](2026-05-13-v2-phase-0-roadmap-design.md) (Phase 9)
Issue: [#10](https://github.com/barriault/gygaxagain/issues/10)

## Goals

- Close the asymmetry-coverage gap at the component layer. Player ViewModels and prompt builders already have `leak_secrets_of` assertions (delivered in Phases 5 and 8); the 16 `Play::*Component` specs do not, and that is the load-bearing gap to close.
- Lock in coverage for future v2 phases via a load-time guard that fails CI when new player-facing classes ship without an asymmetry assertion. This is the lightweight v2 equivalent of the "Brakeman-like analyzer" the Phase 0 spec wishes for.
- Run the first end-to-end playtest on production. Capture findings. Treat asymmetry violations as structural failures of the test infrastructure, not content issues.
- Fix anything that breaks gameplay flow or violates asymmetry. Defer everything else to a follow-up issue.

## Non-goals

- New gameplay features. Factions ticking offscreen, revelations, threads, modules — all Phase 10+.
- Fuzz-testing, controller-tree audits, error-page hardening. Approach C scope from the brainstorm. Defer until a real bug motivates them.
- Multi-session campaigns. One full session is the requirement.
- Production hardening unrelated to asymmetry (perf budgets, Sentry, structured monitoring) — separately scoped.

## Current state (as of brainstorm)

What already exists, captured here so the implementation plan doesn't accidentally re-do it:

**Asymmetry primitives** ([`spec/support/matchers/not_to_leak.rb`](../../../spec/support/matchers/not_to_leak.rb)):
- `leak_secrets_of(*records)` — dynamic check that the subject's rendered string does not contain any `label` or `content` from the records' `*Secret` rows. Raises `ArgumentError` if no secrets are seeded (prevents vacuous passes).
- `expose_attrs_via(association_name)` — structural check that a ViewModel class does not expose secret associations.

**Secret tables that actually exist in v2:** only `faction_secrets` and `npc_secrets`. The Phase 0 spec mentions `revelation_secrets` and `module_secrets`; those are Phase 11 / Phase 14 work, not Phase 9.

**Player ViewModel asymmetry coverage** (✅ already in place):
- `Player::FactionViewModel` — uses both matchers
- `Player::NpcViewModel` — uses both matchers
- `Player::SceneViewModel` — uses `leak_secrets_of(faction, npc)` + structural check
- `Player::CampaignViewModel` — uses `leak_secrets_of(faction, npc)`
- `Player::EventViewModel` — uses `leak_secrets_of(faction, npc)`

**Prompt-builder asymmetry coverage** (✅ already in place):
- `Narrator::PromptBuilder` — `leak_secrets_of(faction, npc)` against rendered prompt
- `Narrator::AuditPromptBuilder` — `leak_secrets_of(faction, npc)` against rendered prompt

**Play component asymmetry coverage** (❌ the gap):
- All 16 `Play::*Component` specs exist (delivered in Phase 6–8) but none currently call `leak_secrets_of`.

## Component asymmetry sweep

The 16 components split three ways.

### Group 1 — Renders Player ViewModels directly. Must assert `leak_secrets_of` (8 components)

These accept a Player ViewModel as input and render fields drawn from it. The asymmetry assertion is the load-bearing test for each.

- `Play::Events::NarrationComponent` — narration event renderer. The riskiest: narration text is LLM-generated and persisted to `events.payload`. If `Narrator::PromptBuilder` ever did leak, this is where the leak surfaces.
- `Play::Events::PlayerActionComponent`
- `Play::Events::DiceRollComponent`
- `Play::Events::OracleQueryComponent`
- `Play::Events::SceneTransitionComponent`
- `Play::Scenes::LogComponent` — composite that iterates events through the dispatcher.
- `Play::Scenes::PlayComponent` — top-level scene wrapper.
- `Play::Campaigns::ScenePickerComponent` — lists scenes in a campaign.

**Standard assertion shape** (each spec adds a context block):

```ruby
context "asymmetry" do
  let!(:faction_secret) { create(:faction_secret, faction: faction, label: "Hidden agenda", content: "destroy the city") }
  let!(:npc_secret)     { create(:npc_secret,     npc: npc,         label: "True name",     content: "...") }

  it "does not leak secrets when rendered with a Player ViewModel" do
    render_inline(described_class.new(<viewmodel constructed with faction + npc>))
    expect(rendered_content).not_to leak_secrets_of(faction, npc)
  end
end
```

Each component's existing spec factories already construct the right ViewModel shape; only the seeded secrets + assertion are added.

### Group 2 — Pure UI scaffolds. Document exemption (6 components)

These either accept no ViewModel input or render no campaign-scoped data. They get a one-line marker comment in their spec and are listed in the meta-spec's exempt allowlist.

- `Play::HomeComponent` — static landing
- `Play::Dice::FormComponent` — input form
- `Play::Oracle::FormComponent` — input form
- `Play::Narration::FormComponent` — input form (action submission only)
- `Play::Scenes::InputDockComponent` — input dock shell
- `Play::Campaigns::PlaceholderComponent` — empty-state placeholder

Marker comment template, placed at top of the relevant spec's `describe` block:

```ruby
# Asymmetry-exempt: renders no campaign-scoped data.
# See spec/asymmetry/coverage_spec.rb EXEMPT_COMPONENTS.
```

### Group 3 — Edge cases (2 components)

- `Play::Campaigns::PickerComponent` — renders the user's campaigns (`Player::CampaignViewModel`-shaped data, name only). Today no leak surface exists, but the matcher costs nothing and guards against future drift. **Treated as Group 1.**
- `Play::Events::Component` — the dispatcher module. Not a renderable component; its existing spec already asserts REGISTRY routing. **No `leak_secrets_of` assertion needed; not subject to the meta-spec.**

### Summary count

- Group 1 + Group 3-rendering: **9 components get new asymmetry assertions.**
- Group 2: **6 components get marker comments only.**
- Dispatcher: **1 component, no change.**
- Total: 16, matches the inventory.

## Meta-spec — load-time coverage guard

A single spec walks the player-facing namespaces at load time and asserts coverage.

**Location:** `spec/asymmetry/coverage_spec.rb`

**Three checks:**

1. **`Player::*ViewModel` coverage.** For every class in `Player::` whose name ends in `ViewModel`, the spec asserts that `spec/view_models/player/<snake_name>_spec.rb` exists and contains the string `leak_secrets_of`.

2. **`Play::*Component` coverage.** For every class in `Play::` whose name ends in `Component`, except those listed in the exempt allowlist, the spec asserts that `spec/components/play/<path>_spec.rb` exists and contains `leak_secrets_of`.

3. **`Narrator::*PromptBuilder` coverage.** For every class under `Narrator::` whose name matches `*PromptBuilder`, the spec asserts that its spec file contains `leak_secrets_of`.

**Exempt allowlist (Group 2):**

```ruby
EXEMPT_COMPONENTS = {
  "Play::HomeComponent"                   => "static landing, no ViewModel input",
  "Play::Dice::FormComponent"             => "input form, no campaign-scoped data",
  "Play::Oracle::FormComponent"           => "input form, no campaign-scoped data",
  "Play::Narration::FormComponent"        => "input form (action submission only)",
  "Play::Scenes::InputDockComponent"      => "input dock shell, no campaign-scoped data",
  "Play::Campaigns::PlaceholderComponent" => "empty-state placeholder"
}.freeze
```

`Play::Events::Component` (the dispatcher module) is excluded from discovery entirely — it is not a `ViewComponent::Base` subclass and the discovery query filters by ancestry.

**Discovery technique:** the spec calls `Rails.application.eager_load!` to populate the constant table, then walks `Player.constants` / `Play.constants` recursively. For component discovery, the filter is `c.is_a?(Class) && c < ViewComponent::Base` — this naturally excludes `Play::Events::Component`, which is a `Module`, not a class. For ViewModel discovery, the filter is `c.is_a?(Class) && c.name.end_with?("ViewModel")`. The same walk applies under `Narrator::` for prompt builders, with filter `c.is_a?(Class) && c.name.end_with?("PromptBuilder")`.

**Matcher detection — string-match, not eval.** The spec reads the corresponding spec file as a string and asserts it contains `leak_secrets_of`. This catches the "I forgot entirely" case, which is the common mistake. It does *not* catch:
- An assertion written incorrectly (matcher present but wrong subject).
- An assertion that doesn't seed any secrets — though the matcher itself raises `ArgumentError` in that case, so the spec fails another way.
- A helper that wraps the matcher in a different method name.

Code review still has to catch those. The guard is a coverage floor, not a correctness check.

**Failure-mode message** when a new player-facing class ships without coverage:

```
Player::RevelationViewModel: no `leak_secrets_of` assertion found in
spec/view_models/player/revelation_view_model_spec.rb (or the file is
missing). Add asymmetry coverage or — if intentionally exempt — extend
the EXEMPT_COMPONENTS allowlist in spec/asymmetry/coverage_spec.rb
with a reason.
```

**Why this matters starting Phase 10.** Phase 10 (faction clocks), Phase 11 (revelations), Phase 12 (threads), Phase 14 (modules) each introduce new `Player::*ViewModel` and `Play::*Component` classes. Without the guard, the first PR that lands a new ViewModel without coverage relies entirely on review discipline. The guard makes the omission a CI failure.

## Playtest protocol

A single dedicated session, structured enough to surface bugs but loose enough to feel like real play. Three artifacts: an in-fiction session log, an out-of-fiction findings log, and N filed sub-issues.

### Preconditions (verified before the session starts)

- `gygaxagain.com` and `admin.gygaxagain.com` both reachable, SSL valid, signed-in.
- At least one Campaign exists in admin with:
  - 2–3 Factions, each with at least one FactionSecret.
  - 3–5 NPCs, several with NpcSecret rows.
  - 1–2 Scenes pre-created.
- Chaos factor set in admin.
- Anthropic API key wired; a recent `llm_calls` row from a `admin/diagnostics/llm` ping confirms the path is live.
- Heroku app is in the maintenance-free state — no in-flight migrations, no recent deploys with unverified state.

### Session shape

1. Sign in on a real device (recommended: phone or tablet, not the dev machine — surfaces responsive issues).
2. Navigate to the play surface, pick a campaign, pick a scene, begin.
3. Play through at least:
   - **5+ narration round-trips** (player action → streamed narration).
   - **2+ dice rolls** — one inline-roll chip from the dice form, one freeform expression.
   - **2+ oracle queries** — one in the likely / very-likely range, one chaos-amplified.
   - **1+ scene transition** (end one scene, start the next).
   - **1 scene close** → SceneAuditJob runs → admin verifies an audit row was written.
4. Session-end: scene closed cleanly, audit visible in admin, `llm_calls` rows present with non-zero cost. Spot-check at least one prompt payload to confirm no hidden state appears.

### Findings log

A single markdown file at `docs/superpowers/playtests/2026-05-DD-phase-9-shake-out.md` (date set at session start):

```markdown
## Session log
[narrative recap, brief — for posterity]

## Findings
- [F1] **Blocker / Asymmetry / Polish** — short title
  Reproduction: ...
  Sub-issue: #N (filed)
- [F2] ...
```

**During-session capture rule:** notice → one-line note in the file → keep playing. Do not context-switch into debugging mid-session unless something is fully broken (no narration coming back, can't sign in, etc.). The rhythm of the play matters as much as the findings.

**Why production specifically.** The Phase 0 spec is explicit that the playtest happens on production. Local dev runs Solid Queue inline, uses localhost cookies, has no real network latency on streaming, has different SSL behavior. Several classes of bug only surface on Heroku — slow streaming chunk arrival, cross-subdomain cookie eviction under real DNS, Solid Queue worker pickup latency.

## Bug triage discipline

### The two-bucket rule

| Bucket | Definition | Where it goes | Gates Phase 9 close? |
|---|---|---|---|
| **Blocker** | (a) Gameplay flow broken end-to-end OR (b) asymmetry violation of any kind (hidden content reaches player surface or LLM prompt) | New sub-issue of #10, labeled `phase-9-blocker` | Yes — must close before #10 closes |
| **Polish** | Wording, layout, copy, ergonomics, perf, "would be nice" | New sub-issue under a new `v2 Phase 9 — playtest follow-up` parent issue, labeled `phase-9-followup` | No — deferred to a later phase |

### Asymmetry violations are always blockers

No judgment call. Even if the leaked content seems innocuous, an asymmetry violation is treated as a structural failure of the boundary, not a content issue. Two reasons:

1. The whole v2 thesis is "asymmetry by construction, testable." If a leak gets through, the test infrastructure failed too. Both need fixing.
2. The fix is almost always: *add a `leak_secrets_of` assertion to whichever code path was missing one, watch it fail, then fix the leak.*

### Asymmetry-violation incident report

If any violations are found, the sub-issue body includes (in addition to a reproduction):

- The exact secret label/content that leaked.
- The code path that exposed it (which ViewModel, which component, which prompt builder, which controller action).
- Why existing tests didn't catch it (gap in matcher? matcher applied but to wrong subject? no assertion existed at this layer?).
- The matcher assertion that *would* have caught it, added as part of the fix.

The last bullet is what compounds. Each violation strengthens the suite against the class of bug, so the next playtest is less risky than this one.

### Playtest follow-up parent issue

When the playtest is done, file a single new issue titled `v2 Phase 9 — playtest follow-up`. All polish bugs become sub-issues of it. This keeps #10 clean — #10 closes when blockers are fixed, and the follow-up parent becomes the index for the next pass of work.

## Phase close criteria

Phase 9 closes (and issue #10 closes) when *all* of these are true:

**Coverage:**

- [ ] All 9 Group-1+3 `Play::*Component` specs assert `leak_secrets_of` against a Player ViewModel rendered with at least one `*Secret` row seeded.
- [ ] All 6 Group-2 exempt components have a marker comment in their spec.
- [ ] `spec/asymmetry/coverage_spec.rb` exists, runs in CI, currently passes, and demonstrably fails if a new player-facing class lands without coverage (verified via a one-off scratch experiment, then reverted).
- [ ] All 5 existing `Player::*ViewModel` specs still pass with their existing `leak_secrets_of` assertions (regression check — should be free).
- [ ] Both prompt-builder specs still pass with their existing `leak_secrets_of` assertions.

**Playtest:**

- [ ] One full session played on production (gygaxagain.com), meeting the session-shape checklist (5+ narrations, 2+ dice, 2+ oracle, 1+ scene transition, 1 scene close + audit).
- [ ] `docs/superpowers/playtests/<date>-phase-9-shake-out.md` exists with session log + findings.
- [ ] `llm_calls` rows from the session are inspected; non-zero costs recorded; full prompts spot-checked to confirm no hidden state appears.

**Triage:**

- [ ] All blockers (gameplay-broken or asymmetry-violating) are fixed and verified on production.
- [ ] All polish bugs are filed as sub-issues under the `v2 Phase 9 — playtest follow-up` parent issue.
- [ ] No asymmetry violations remain open. If any were found, the corresponding new test that catches them is in place and green.

**Issue hygiene:**

- [ ] Issue #10's body is updated with links to: this design spec, the implementation plan, the playtest log, and the follow-up parent issue.
- [ ] The v2 parent issue #1 references #10 as "Phase 9 complete — v2 playing-MVP shipped."

Once all checked, #10 closes. The v2 parent issue #1 closes immediately after — its only remaining acceptance criterion is Phase 9 closure.

## File inventory (rough sketch for the plan)

The writing-plans pass will sequence these into ordered tasks. Listed here so the plan author has the rough shape.

**New files (1):**
- `spec/asymmetry/coverage_spec.rb` — the meta-spec.

**Modified spec files (15):**
- 9 component specs gain asymmetry contexts:
  - `spec/components/play/events/narration_component_spec.rb`
  - `spec/components/play/events/player_action_component_spec.rb`
  - `spec/components/play/events/dice_roll_component_spec.rb`
  - `spec/components/play/events/oracle_query_component_spec.rb`
  - `spec/components/play/events/scene_transition_component_spec.rb`
  - `spec/components/play/scenes/log_component_spec.rb`
  - `spec/components/play/scenes/play_component_spec.rb`
  - `spec/components/play/campaigns/scene_picker_component_spec.rb`
  - `spec/components/play/campaigns/picker_component_spec.rb`
- 6 component specs gain marker comments:
  - `spec/components/play/home_component_spec.rb`
  - `spec/components/play/dice/form_component_spec.rb`
  - `spec/components/play/oracle/form_component_spec.rb`
  - `spec/components/play/narration/form_component_spec.rb`
  - `spec/components/play/scenes/input_dock_component_spec.rb`
  - `spec/components/play/campaigns/placeholder_component_spec.rb`

**Playtest artifact:**
- `docs/superpowers/playtests/2026-05-DD-phase-9-shake-out.md` — created at session time.

**Issue work:**
- New parent issue: `v2 Phase 9 — playtest follow-up`.
- Sub-issues filed under #10 (blockers) and the follow-up parent (polish).
- Issue #10 body updated with links and closed.
- Issue #1 closed.

## Out of scope (revisited)

For clarity, the following are *not* part of Phase 9 and should not creep in during implementation:

- New Player ViewModels or Play components. (Phase 10+ work.)
- Changing the asymmetry matcher API itself. Stable since Phase 5.
- A custom RuboCop / Brakeman cop. The meta-spec is the lightweight alternative.
- Performance work on streaming or audit jobs. Filed as polish if surfaced.
- Devise / auth changes. Filed as polish if surfaced; only a blocker if sign-in itself is broken.

## Open questions (deferred until implementation)

- Date placeholder in the playtest filename — set on the day the session runs.
- Whether the meta-spec belongs at `spec/asymmetry/` or under `spec/support/`. The current proposal puts it at `spec/asymmetry/coverage_spec.rb` so it's discoverable as a test rather than a helper. Plan author can revisit if there's a strong reason.
