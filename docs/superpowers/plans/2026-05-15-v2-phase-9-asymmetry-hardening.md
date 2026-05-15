# v2 Phase 9 — Asymmetry Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the one remaining component-layer asymmetry-coverage gap, add a load-time meta-spec that prevents future regressions, then run the first end-to-end production playtest and triage findings.

**Architecture:** Two-layer test discipline already exists in v2 (a `leak_secrets_of` matcher + per-class assertions). Phase 8 work landed the matcher in 13 of 16 player-facing components. Phase 9 adds it to the 14th (`Play::Campaigns::PickerComponent`), marks the one structurally exempt component (`Play::HomeComponent`), and adds `spec/asymmetry/coverage_spec.rb` — a meta-spec that walks the `Player::`, `Play::`, and `Narrator::` namespaces and fails CI when any non-exempt class lacks a `leak_secrets_of` assertion in its spec file.

**Tech Stack:** Ruby 3 / Rails 8 / RSpec / FactoryBot / ViewComponent. Existing matcher at `spec/support/matchers/not_to_leak.rb`. Existing factories `faction`, `faction_secret`, `npc`, `npc_secret`, `campaign`, `scene`, `event`. Existing convention: `describe "asymmetry"` block at the end of each component spec, seeding secrets in a `before` and rendering with `render_inline`.

---

## Reference: design spec

The design this plan implements lives at [`docs/superpowers/specs/2026-05-15-v2-phase-9-asymmetry-hardening-design.md`](../specs/2026-05-15-v2-phase-9-asymmetry-hardening-design.md). The plan author corrected one fact in that spec during this writing pass: 13/16 component specs already have `leak_secrets_of` (Phase 8 work), not zero as the original brainstorm assumed. The plan reflects the corrected scope.

## File Structure

**New file (1):**
- `spec/asymmetry/coverage_spec.rb` — the meta-spec. Single file, single responsibility: at load time, walk player-facing namespaces and assert each non-exempt class has a `leak_secrets_of` assertion in its spec file.

**Modified files (2):**
- `spec/components/play/campaigns/picker_component_spec.rb` — gains an `asymmetry` describe block following the Phase 8 convention.
- `spec/components/play/home_component_spec.rb` — gains a single marker comment inside `RSpec.describe`.

**Operational artifacts (created during execution):**
- `docs/superpowers/playtests/<date>-phase-9-shake-out.md` — playtest log + findings.
- N GitHub sub-issues filed during triage.

---

## Task 1: Add asymmetry assertion to PickerComponent spec

**Why:** `Play::Campaigns::PickerComponent` renders a collection of user campaigns. It does not currently render any field that carries hidden state, but the matcher is cheap insurance against future drift, and the meta-spec (built in later tasks) will require this assertion.

**Files:**
- Modify: `spec/components/play/campaigns/picker_component_spec.rb`

**Reference:** existing Phase 8 convention from [`spec/components/play/dice/form_component_spec.rb`](../../../spec/components/play/dice/form_component_spec.rb) lines 111–124 — the same template applies.

- [ ] **Step 1: Read the current spec to see the existing structure**

Run: `cat spec/components/play/campaigns/picker_component_spec.rb`

Expected: 19-line spec with two `it` blocks ("renders one link per campaign", "renders an empty-state when given an empty collection"). No `describe "asymmetry"` block.

- [ ] **Step 2: Add the asymmetry describe block to the spec**

Insert this block immediately before the closing `end` of the `RSpec.describe`:

```ruby
  describe "asymmetry" do
    let(:user)     { create(:user) }
    let(:campaign) { create(:campaign, user: user) }
    let(:faction)  { create(:faction, campaign: campaign) }
    let(:npc)      { create(:npc,     campaign: campaign) }

    before do
      create(:faction_secret, faction: faction, label: "hidden temple", content: "in the swamp")
      create(:npc_secret,     npc: npc,         label: "true identity", content: "is a doppelganger")
    end

    it "does not leak secrets of related records" do
      rendered = render_inline(described_class.new(campaigns: [ campaign ])).to_s
      expect(rendered).not_to leak_secrets_of(faction, npc)
    end
  end
```

- [ ] **Step 3: Run the picker spec**

Run: `bundle exec rspec spec/components/play/campaigns/picker_component_spec.rb -f documentation`

Expected: 3 examples, 0 failures. The new "does not leak secrets of related records" example passes (the picker only renders `campaign.name`, so no secret content is rendered).

- [ ] **Step 4: Sanity-check the matcher actually ran (not vacuous)**

Temporarily mutate the test: change `expect(rendered).not_to` to `expect(rendered).to`. Re-run the spec.

Expected: the assertion fails with "expected subject to leak secrets of Faction, Npc, but found none". This confirms the matcher is exercising real seeded secrets, not silently passing.

Revert the mutation.

Run: `bundle exec rspec spec/components/play/campaigns/picker_component_spec.rb -f documentation`

Expected: 3 examples, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add spec/components/play/campaigns/picker_component_spec.rb
git commit -m "Add asymmetry coverage to PickerComponent spec (Phase 9)

Closes the last component-layer leak_secrets_of gap. Picker renders
only campaign.name today, but the assertion guards against future
drift and satisfies the upcoming asymmetry meta-spec."
```

---

## Task 2: Add asymmetry-exempt marker to HomeComponent spec

**Why:** `Play::HomeComponent` is a static landing page with no campaign-scoped input. It is structurally incapable of leaking secrets, and the meta-spec needs to know it's intentionally exempt rather than accidentally uncovered.

**Files:**
- Modify: `spec/components/play/home_component_spec.rb`

- [ ] **Step 1: Open the spec and add the marker comment**

Insert this comment immediately inside the `RSpec.describe Play::HomeComponent, type: :component do` block, before the first `it`:

```ruby
  # Asymmetry-exempt: static landing, no ViewModel input.
  # See EXEMPT_COMPONENTS in spec/asymmetry/coverage_spec.rb.
```

After editing, the full file should look like:

```ruby
require "rails_helper"

RSpec.describe Play::HomeComponent, type: :component do
  # Asymmetry-exempt: static landing, no ViewModel input.
  # See EXEMPT_COMPONENTS in spec/asymmetry/coverage_spec.rb.

  it "renders the project name, tagline, and private-alpha tag" do
    render_inline(described_class.new)
    expect(page).to have_text("gygaxagain")
    expect(page).to have_text(/solo D&D/i)
    expect(page).to have_text(/private alpha/i)
  end
end
```

- [ ] **Step 2: Run the spec to confirm it still passes**

Run: `bundle exec rspec spec/components/play/home_component_spec.rb -f documentation`

Expected: 1 example, 0 failures.

- [ ] **Step 3: Commit**

```bash
git add spec/components/play/home_component_spec.rb
git commit -m "Mark HomeComponent spec as asymmetry-exempt (Phase 9)

Static landing page with no ViewModel input — structurally cannot
leak. Marker references the upcoming EXEMPT_COMPONENTS allowlist."
```

---

## Task 3: Create the meta-spec skeleton

**Why:** This file is the load-time guard that fails CI when a new player-facing class ships without asymmetry coverage. Tasks 4–6 will fill in the three coverage checks (ViewModels, components, prompt builders). This task lays down the skeleton — file, helpers, allowlist — so the next three tasks have somewhere to plug into.

**Files:**
- Create: `spec/asymmetry/coverage_spec.rb`

- [ ] **Step 1: Create the directory and file**

Run: `mkdir -p spec/asymmetry`

Then create `spec/asymmetry/coverage_spec.rb` with the following content:

```ruby
require "rails_helper"

# Asymmetry coverage meta-spec.
#
# Walks the player-facing namespaces at load time and asserts every
# non-exempt class has a leak_secrets_of assertion in its spec file.
# String-matches the spec file (not eval) — a coverage floor, not a
# correctness check. Code review still catches assertions that are
# present but written incorrectly.
RSpec.describe "Asymmetry coverage", type: :meta do
  before(:all) { Rails.application.eager_load! }

  EXEMPT_COMPONENTS = {
    "Play::HomeComponent" => "static landing, no ViewModel input"
  }.freeze

  # Returns the absolute spec path for a given player-facing class.
  # Mirrors Rails conventions:
  #   Player::FactionViewModel    -> spec/view_models/player/faction_view_model_spec.rb
  #   Play::Events::NarrationComponent -> spec/components/play/events/narration_component_spec.rb
  #   Narrator::PromptBuilder     -> spec/lib/narrator/prompt_builder_spec.rb
  def spec_file_for(klass)
    underscored = klass.name.underscore
    case klass.name
    when /\APlayer::.+ViewModel\z/   then Rails.root.join("spec/view_models/#{underscored}_spec.rb")
    when /\APlay::.+Component\z/     then Rails.root.join("spec/components/#{underscored}_spec.rb")
    when /\ANarrator::.+\z/          then Rails.root.join("spec/lib/#{underscored}_spec.rb")
    end
  end

  # Walks a module recursively, collecting all constants it owns
  # (transitively). Returns Class and Module objects.
  def descendants_of(mod)
    return [] unless mod.is_a?(Module)
    collected = []
    walk = ->(m) do
      m.constants.each do |sym|
        c = m.const_get(sym)
        next unless c.is_a?(Module) && c.name&.start_with?(m.name + "::")
        collected << c
        walk.call(c) unless c.is_a?(Class)
      end
    end
    walk.call(mod)
    collected
  end

  def assert_coverage_for(klass)
    path = spec_file_for(klass)
    return "#{klass.name}: spec_file_for returned nil — naming convention mismatch?" unless path
    return "#{klass.name}: spec file missing at #{path}" unless path.exist?
    return "#{klass.name}: spec at #{path} does not contain `leak_secrets_of`" unless path.read.include?("leak_secrets_of")
    nil
  end

  # Coverage checks are added in Tasks 4–6.
end
```

- [ ] **Step 2: Run the meta-spec to confirm it loads cleanly**

Run: `bundle exec rspec spec/asymmetry/coverage_spec.rb -f documentation`

Expected: 0 examples, 0 failures. (No `it` blocks yet — file loads, eager_load runs, no errors.)

- [ ] **Step 3: Commit**

```bash
git add spec/asymmetry/coverage_spec.rb
git commit -m "Add asymmetry coverage meta-spec skeleton (Phase 9)

EXEMPT_COMPONENTS allowlist, spec_file_for path helper, descendants_of
namespace walker, assert_coverage_for predicate. Tasks 4–6 add the
ViewModel, Component, and PromptBuilder coverage assertions."
```

---

## Task 4: Add Player ViewModel coverage check to the meta-spec

**Why:** Every `Player::*ViewModel` represents a player-facing rendering boundary. The first of the three coverage checks asserts each one has a `leak_secrets_of` assertion in its corresponding spec file.

**Files:**
- Modify: `spec/asymmetry/coverage_spec.rb`

- [ ] **Step 1: Add the Player ViewModel describe block**

Insert this block immediately before the closing `end` of `RSpec.describe "Asymmetry coverage"`:

```ruby
  describe "Player::*ViewModel coverage" do
    it "every Player::*ViewModel has a leak_secrets_of assertion in its spec" do
      view_models = descendants_of(Player)
        .select { |c| c.is_a?(Class) && c.name.end_with?("ViewModel") }

      expect(view_models).not_to be_empty,
        "Sanity: no Player::*ViewModel classes were discovered. " \
          "Did Rails.application.eager_load! actually run?"

      problems = view_models.map { |vm| assert_coverage_for(vm) }.compact

      expect(problems).to be_empty,
        -> { "Player ViewModel coverage gaps:\n" + problems.map { |p| "  - #{p}" }.join("\n") }
    end
  end
```

- [ ] **Step 2: Run the meta-spec**

Run: `bundle exec rspec spec/asymmetry/coverage_spec.rb -f documentation`

Expected: 1 example, 0 failures. (All 5 existing `Player::*ViewModel` specs already call `leak_secrets_of`.)

- [ ] **Step 3: Confirm discovery actually found the ViewModels**

Run: `bundle exec rspec spec/asymmetry/coverage_spec.rb -f documentation 2>&1 | head -30`

The example name should appear in output. To verify discovery worked, temporarily insert `puts view_models.map(&:name).inspect` before the `expect(problems)` line and re-run.

Expected output should include (at minimum):
```
["Player::CampaignViewModel", "Player::EventViewModel", "Player::FactionViewModel", "Player::NpcViewModel", "Player::SceneViewModel"]
```

Remove the `puts` line after confirming.

- [ ] **Step 4: Commit**

```bash
git add spec/asymmetry/coverage_spec.rb
git commit -m "Add Player::*ViewModel coverage check to asymmetry meta-spec

Walks the Player namespace at load time and asserts each ViewModel
class has a leak_secrets_of assertion in its spec file. All 5
existing ViewModels already satisfy this check."
```

---

## Task 5: Add Play Component coverage check to the meta-spec

**Why:** Every `Play::*Component` is a player-facing rendering boundary at the view layer. This check asserts each one — except those listed in `EXEMPT_COMPONENTS` — has a `leak_secrets_of` assertion in its spec.

**Files:**
- Modify: `spec/asymmetry/coverage_spec.rb`

- [ ] **Step 1: Add the Play Component describe block**

Insert this block immediately before the closing `end` of `RSpec.describe "Asymmetry coverage"` (after the Player ViewModel block from Task 4):

```ruby
  describe "Play::*Component coverage" do
    it "every non-exempt Play::*Component has a leak_secrets_of assertion in its spec" do
      components = descendants_of(Play)
        .select { |c| c.is_a?(Class) && c < ViewComponent::Base }

      expect(components).not_to be_empty,
        "Sanity: no Play::*Component classes were discovered."

      non_exempt = components.reject { |c| EXEMPT_COMPONENTS.key?(c.name) }
      problems   = non_exempt.map { |c| assert_coverage_for(c) }.compact

      expect(problems).to be_empty,
        -> {
          "Play component coverage gaps:\n" +
            problems.map { |p| "  - #{p}" }.join("\n") +
            "\n\nAdd asymmetry coverage or — if intentionally exempt — " \
              "extend EXEMPT_COMPONENTS in spec/asymmetry/coverage_spec.rb with a reason."
        }
    end
  end
```

- [ ] **Step 2: Run the meta-spec**

Run: `bundle exec rspec spec/asymmetry/coverage_spec.rb -f documentation`

Expected: 2 examples, 0 failures.

- [ ] **Step 3: Confirm discovery filters out the dispatcher module**

Run: `bundle exec rspec spec/asymmetry/coverage_spec.rb -f documentation`

The check passes because `Play::Events::Component` is a `Module` (not a `Class`) and is filtered out by `c.is_a?(Class) && c < ViewComponent::Base`. To verify, temporarily insert `puts components.map(&:name).sort` before the `expect(problems)` line and re-run.

Expected output should include all 15 ViewComponent classes (the 13 Group-A + Group-B `PickerComponent` + Group-C `HomeComponent`) and **not** `Play::Events::Component`.

Remove the `puts` line after confirming.

- [ ] **Step 4: Commit**

```bash
git add spec/asymmetry/coverage_spec.rb
git commit -m "Add Play::*Component coverage check to asymmetry meta-spec

Walks the Play namespace at load time and asserts each ViewComponent
subclass has a leak_secrets_of assertion in its spec, unless listed
in EXEMPT_COMPONENTS. All 15 components (13 covered + 1 added in
Task 1 + 1 exempt) satisfy this check."
```

---

## Task 6: Add Narrator PromptBuilder coverage check to the meta-spec

**Why:** Prompt builders are the third class of player-facing surface — they construct prompts sent to the LLM. A leak at the builder level becomes a permanent record in `llm_calls.prompt_payload`. This check asserts each `Narrator::*PromptBuilder` has a `leak_secrets_of` assertion in its spec.

**Files:**
- Modify: `spec/asymmetry/coverage_spec.rb`

- [ ] **Step 1: Add the PromptBuilder describe block**

Insert this block immediately before the closing `end` of `RSpec.describe "Asymmetry coverage"` (after the Play Component block from Task 5):

```ruby
  describe "Narrator::*PromptBuilder coverage" do
    it "every Narrator::*PromptBuilder has a leak_secrets_of assertion in its spec" do
      builders = descendants_of(Narrator)
        .select { |c| c.is_a?(Class) && c.name.end_with?("PromptBuilder") }

      expect(builders).not_to be_empty,
        "Sanity: no Narrator::*PromptBuilder classes were discovered."

      problems = builders.map { |b| assert_coverage_for(b) }.compact

      expect(problems).to be_empty,
        -> { "Narrator PromptBuilder coverage gaps:\n" + problems.map { |p| "  - #{p}" }.join("\n") }
    end
  end
```

- [ ] **Step 2: Run the meta-spec**

Run: `bundle exec rspec spec/asymmetry/coverage_spec.rb -f documentation`

Expected: 3 examples, 0 failures. The check finds `Narrator::PromptBuilder` and `Narrator::AuditPromptBuilder` and confirms both specs call `leak_secrets_of`.

- [ ] **Step 3: Commit**

```bash
git add spec/asymmetry/coverage_spec.rb
git commit -m "Add Narrator::*PromptBuilder coverage check to asymmetry meta-spec

Walks the Narrator namespace at load time and asserts each
PromptBuilder class has a leak_secrets_of assertion in its spec.
PromptBuilder and AuditPromptBuilder already satisfy this check."
```

---

## Task 7: Verify meta-spec catches a regression

**Why:** A meta-spec that always passes is indistinguishable from a meta-spec that never runs. This task confirms the meta-spec actually fails when coverage is missing — a one-off experiment, immediately reverted.

**Files:** No persistent changes. Temporary mutation of one spec.

- [ ] **Step 1: Run the full meta-spec, confirm it passes**

Run: `bundle exec rspec spec/asymmetry/coverage_spec.rb -f documentation`

Expected: 3 examples, 0 failures.

- [ ] **Step 2: Temporarily break coverage on PickerComponent**

Open `spec/components/play/campaigns/picker_component_spec.rb`. **Replace** (not comment out — the meta-spec uses substring matching, so a commented-out `leak_secrets_of` still satisfies the check) the line:

```ruby
      expect(rendered).not_to leak_secrets_of(faction, npc)
```

with:

```ruby
      expect(rendered).to be_a(String)
```

This removes the string `leak_secrets_of` from the file entirely, which is what the meta-spec's `file.read.include?("leak_secrets_of")` check is looking for.

- [ ] **Step 3: Re-run the meta-spec, confirm it now fails**

Run: `bundle exec rspec spec/asymmetry/coverage_spec.rb -f documentation`

Expected: 3 examples, **1 failure**. The failure message should include:

```
Play component coverage gaps:
  - Play::Campaigns::PickerComponent: spec at <abs path>/spec/components/play/campaigns/picker_component_spec.rb does not contain `leak_secrets_of`
```

If the message is unclear or the path is wrong, the meta-spec's failure-message formatting needs adjustment — fix before proceeding.

- [ ] **Step 4: Revert the temporary mutation**

Restore the original line:

```ruby
      expect(rendered).not_to leak_secrets_of(faction, npc)
```

- [ ] **Step 5: Re-run the meta-spec, confirm it passes again**

Run: `bundle exec rspec spec/asymmetry/coverage_spec.rb -f documentation`

Expected: 3 examples, 0 failures.

- [ ] **Step 6: Confirm no uncommitted changes**

Run: `git status`

Expected: working tree clean. No commit required for this task (it's a verification step with no persistent change).

---

## Task 8: Run the full test suite and confirm green

**Why:** Before moving to the playtest, every spec (including the new meta-spec) must be green. If anything broke during the meta-spec construction, this is where it surfaces.

**Files:** None modified.

- [ ] **Step 1: Run the full RSpec suite**

Run: `bundle exec rspec`

Expected: all examples pass, 0 failures. The new meta-spec contributes 3 examples; the new picker asymmetry assertion contributes 1.

- [ ] **Step 2: Run RuboCop and erb_lint**

Run: `bundle exec rubocop && bundle exec erb_lint --lint-all`

Expected: both clean.

- [ ] **Step 3: Run Brakeman**

Run: `bundle exec brakeman --no-pager`

Expected: no new warnings.

- [ ] **Step 4: Push and verify CI is green**

Run: `git push origin main`

Then monitor CI:

Run: `gh run watch`

Expected: CI workflow completes successfully.

---

## Task 9: Verify playtest preconditions on production

**Why:** The playtest happens on production specifically (not local dev). Before the session, confirm the deployment is in the expected state and seeded with a campaign ready to play.

**Files:** None modified. This is an operational verification task.

- [ ] **Step 1: Confirm the deployment is reachable**

Open `https://gygaxagain.com` and `https://admin.gygaxagain.com` in a browser.

Expected: both load with valid SSL, render their respective shells.

- [ ] **Step 2: Sign in on production**

Sign in at `https://gygaxagain.com/users/sign_in`.

Expected: successful sign-in; cookie carries to `admin.gygaxagain.com` without re-auth.

- [ ] **Step 3: Verify a playable campaign exists**

Navigate to `https://admin.gygaxagain.com/campaigns`.

Expected: at least one campaign exists with:
- 2–3 factions, each with at least one `faction_secret` row.
- 3–5 NPCs, several with `npc_secret` rows.
- 1–2 scenes pre-created.
- Chaos factor set (default if untouched is fine).

If the campaign is missing any of these, create them now via the admin UI before the playtest.

- [ ] **Step 4: Send a smoke ping through the LLM diagnostic**

Navigate to `https://admin.gygaxagain.com/diagnostics/llm`. Submit a short prompt (e.g., "say hi").

Expected: response renders, an `llm_calls` row is written, non-zero cost recorded. This confirms the Anthropic API key is wired correctly on production.

- [ ] **Step 5: Pick a device for the playtest**

Recommendation: phone or tablet (not the dev machine) to surface responsive-layout issues. The findings log will note which device was used.

No commit for this task — operational verification only.

---

## Task 10: Run the playtest and capture findings

**Why:** This is the shake-out itself: the first end-to-end real play on the v2 deployment. The rhythm rule is *notice → one-line note → keep playing*. Bugs are captured, not debugged mid-session.

**Files:**
- Create: `docs/superpowers/playtests/<YYYY-MM-DD>-phase-9-shake-out.md` (where `<YYYY-MM-DD>` is the session date)

- [ ] **Step 1: Create the findings log**

Replace `<DATE>` with today's date in YYYY-MM-DD format. Create the file:

```bash
mkdir -p docs/superpowers/playtests
```

Create `docs/superpowers/playtests/<DATE>-phase-9-shake-out.md` with this initial scaffold:

```markdown
# Phase 9 shake-out playtest

Date: <DATE>
Device: <phone | tablet | laptop>
Campaign: <name>
Duration: <hh:mm – hh:mm>

## Session log

[Narrative recap — brief. Capture in-fiction beats.]

## Findings

<!--
For each finding:
- [F<n>] **Blocker | Asymmetry | Polish** — short title
  Reproduction: ...
  Sub-issue: #<n> (filed)
-->
```

- [ ] **Step 2: Play through the session-shape checklist**

Sign in on the chosen device, navigate to the play surface, pick the campaign and a starting scene. Play through at minimum:

- **5+ narration round-trips** — declare an action, watch narration stream in.
- **2+ dice rolls** — one inline chip from the dice form, one freeform expression.
- **2+ oracle queries** — one in the likely / very-likely range, one with elevated chaos.
- **1+ scene transition** — end one scene, start the next.
- **1 scene close** — close the active scene; verify in admin that a `scene_audits` row was written by `SceneAuditJob`.

**During the session:** notice a bug or rough edge → add a one-line note to the Findings section of the playtest log → keep playing. Do not debug mid-session unless something is fully broken.

- [ ] **Step 3: Verify llm_calls were recorded**

After the session, in admin (or via Heroku console):

```bash
heroku run rails console
```

Then:

```ruby
LlmCall.where("created_at > ?", 4.hours.ago).count
LlmCall.where("created_at > ?", 4.hours.ago).sum(:total_cost_cents)
```

Expected: a count matching the rough number of LLM-touching events (5+ narrations + 1 audit = ≥6 rows), and a non-zero cost.

- [ ] **Step 4: Spot-check one prompt for hidden state**

```ruby
LlmCall.where("created_at > ?", 4.hours.ago).where(purpose: "narration").last.prompt_payload
```

Expected: the prompt contains the player-facing narration context but no `faction_secret.content`, `npc_secret.content`, or `*_secret.label` strings. If you find any hidden content, that is an asymmetry violation — file it as a blocker in Task 11.

- [ ] **Step 5: Fill in the session log**

Open the playtest markdown file. Write 2–4 paragraphs summarizing the session (what happened in fiction, what the player did, how it played).

- [ ] **Step 6: Commit the playtest log**

```bash
git add docs/superpowers/playtests/<DATE>-phase-9-shake-out.md
git commit -m "Phase 9 shake-out playtest log (<DATE>)

First end-to-end production playtest. <N> findings captured; triage
follows in next commits / sub-issues."
```

---

## Task 11: Triage findings and file sub-issues

**Why:** The findings log is the raw output. This task converts it into actionable GitHub sub-issues, applying the two-bucket rule (blocker vs. polish) from the design spec.

**Files:**
- Modify: `docs/superpowers/playtests/<DATE>-phase-9-shake-out.md` (annotate each finding with its sub-issue link)

- [ ] **Step 1: Walk through each finding and assign a bucket**

For each `[F<n>]` entry in the findings log, decide:

- **Blocker** if: (a) gameplay flow is broken end-to-end (can't sign in, narration doesn't return, scene close fails, audit job crashes) OR (b) any asymmetry violation (any sign of hidden content reaching the player surface or LLM prompt — verified in Task 10 Step 4).
- **Polish** for everything else: wording, layout, copy, ergonomics, perf, "would be nice".

If a finding is ambiguous, default to **polish**. The exception: anything asymmetry-shaped is **always** a blocker, regardless of severity.

- [ ] **Step 2: Create the playtest-followup parent issue**

If there's at least one polish finding, create the parent issue:

```bash
gh issue create \
  --title "v2 Phase 9 — playtest follow-up" \
  --body "$(cat <<'EOF'
## Scope

Parent issue for polish-bucket findings from the Phase 9 shake-out playtest. Each linked sub-issue is a single low-priority improvement that didn't block Phase 9 closure but is worth doing in a follow-up pass.

## Source

- Playtest log: `docs/superpowers/playtests/<DATE>-phase-9-shake-out.md`
- Phase 9 design spec: `docs/superpowers/specs/2026-05-15-v2-phase-9-asymmetry-hardening-design.md`
- Closes-when: each child sub-issue is closed or explicitly deferred to a later phase.

Part of #1.
EOF
)"
```

Note the new issue number; replace `<followup-parent>` with it in subsequent steps.

- [ ] **Step 3: File each blocker as a sub-issue of #10**

For each blocker, run:

```bash
gh issue create \
  --title "Phase 9 blocker: <short title>" \
  --label "phase-9-blocker" \
  --body "$(cat <<'EOF'
## Source

Playtest log: `docs/superpowers/playtests/<DATE>-phase-9-shake-out.md` (finding [F<n>])

## Reproduction

<verbatim repro from the findings log>

## Severity

Blocker: <gameplay-broken | asymmetry-violation>

<for asymmetry violations, include the incident report fields:>
- Secret label/content that leaked: ...
- Code path that exposed it: ...
- Why existing tests didn't catch it: ...
- Matcher assertion that would have caught it (added as part of the fix): ...

Sub-issue of #10.
EOF
)"
```

- [ ] **Step 4: File each polish item as a sub-issue of the follow-up parent**

For each polish finding, run:

```bash
gh issue create \
  --title "<short title>" \
  --label "phase-9-followup" \
  --body "$(cat <<'EOF'
## Source

Playtest log: `docs/superpowers/playtests/<DATE>-phase-9-shake-out.md` (finding [F<n>])

## Detail

<verbatim from the findings log>

Sub-issue of #<followup-parent>.
EOF
)"
```

- [ ] **Step 5: Update the playtest log with sub-issue links**

For each `[F<n>]` in the findings log, replace the `Sub-issue: #<n> (filed)` placeholder with the actual issue number from steps 3/4.

- [ ] **Step 6: Commit the annotated log**

```bash
git add docs/superpowers/playtests/<DATE>-phase-9-shake-out.md
git commit -m "Phase 9 playtest: triage and sub-issue links"
```

---

## Task 12: Fix blockers

**Why:** Per the design spec's "Pragmatic close criterion," Phase 9 closes only after gameplay-blocker and asymmetry-violation bugs are fixed. Polish bugs stay open as follow-up work.

**Files:** Depends entirely on the blockers filed in Task 11. If zero blockers were filed, this task is a no-op.

- [ ] **Step 1: List open blockers**

Run: `gh issue list --label phase-9-blocker --state open`

If the list is empty, mark this task complete and skip to Task 13.

- [ ] **Step 2: For each blocker, do a focused fix**

For each open blocker:

1. Read the issue body's reproduction.
2. Write or extend a failing test that captures the bug. For asymmetry violations, the test is the `leak_secrets_of` assertion that should have caught it. For gameplay breaks, the test is whatever shape the bug demands (request spec, system spec, model spec).
3. Watch the test fail.
4. Fix the production code.
5. Watch the test pass.
6. Run the full suite: `bundle exec rspec`. Expected: green.
7. Commit with reference to the issue: `git commit -m "Fix #<n>: <short desc>"`. The closing keyword auto-closes the issue when pushed.

- [ ] **Step 3: Push the fixes**

Run: `git push origin main`. Monitor CI: `gh run watch`. Expected green.

- [ ] **Step 4: Deploy to production**

Run: `git push heroku main`

Expected: deploy succeeds, release migration runs (no-op for Phase 9), app restarts cleanly.

- [ ] **Step 5: Verify each fix on production**

Reproduce each fixed blocker on `gygaxagain.com`. Confirm the bug no longer occurs. Add a note to the playtest log under each `[F<n>]` entry: `Fixed in commit <sha>, verified on production <YYYY-MM-DD>`.

- [ ] **Step 6: Commit the verification annotations**

```bash
git add docs/superpowers/playtests/<DATE>-phase-9-shake-out.md
git commit -m "Phase 9 playtest: blocker-fix verification notes"
git push origin main
```

- [ ] **Step 7: Confirm no open blockers remain**

Run: `gh issue list --label phase-9-blocker --state open`

Expected: empty list. If anything is still open, do not proceed to Task 13.

---

## Task 13: Phase close — issue body updates and closure

**Why:** Phase 9 is the final v2 playing-MVP phase. Closing it (and #1) requires updating issue bodies with links to the design, plan, playtest log, and follow-up parent, then closing both issues.

**Files:** None modified locally. Issue bodies updated via `gh`.

- [ ] **Step 1: Update issue #10's body with all the Phase 9 artifact links**

Run:

```bash
gh issue edit 10 --body "$(cat <<'EOF'
## Scope

The shake-out phase. Comprehensive asymmetry test coverage across every player-facing surface. First real campaign played end-to-end on the v2 deployment. Bug-fixes and polish. **This phase completes the v2 playing-MVP.**

## Dependencies

- Phases 1–8 (#2–#9) all complete.

## Acceptance criteria

- Every `Player::*` ViewModel has a spec asserting `not_to_leak` against its corresponding `*Secret` table.
- Every `Play::*Component` has a spec asserting it does not render hidden state when rendered with a Player ViewModel as input.
- The repo owner plays one full session (start → multiple scenes → multiple events → session-end audit) on the production deployment. Notes captured.
- Issues uncovered during the shake-out are logged as new sub-issues; this issue closes when shake-out passes.

## Design + planning

- **Phase 0 roadmap:** [`docs/superpowers/specs/2026-05-13-v2-phase-0-roadmap-design.md`](../blob/main/docs/superpowers/specs/2026-05-13-v2-phase-0-roadmap-design.md)
- **Phase 9 design spec:** [`docs/superpowers/specs/2026-05-15-v2-phase-9-asymmetry-hardening-design.md`](../blob/main/docs/superpowers/specs/2026-05-15-v2-phase-9-asymmetry-hardening-design.md)
- **Phase 9 implementation plan:** [`docs/superpowers/plans/2026-05-15-v2-phase-9-asymmetry-hardening.md`](../blob/main/docs/superpowers/plans/2026-05-15-v2-phase-9-asymmetry-hardening.md)
- **Playtest log:** [`docs/superpowers/playtests/<DATE>-phase-9-shake-out.md`](../blob/main/docs/superpowers/playtests/<DATE>-phase-9-shake-out.md)
- **Polish follow-up parent:** #<followup-parent>

Part of #1.
EOF
)"
```

Replace `<DATE>` and `<followup-parent>` with the actual values.

- [ ] **Step 2: Close issue #10**

Run:

```bash
gh issue close 10 --comment "Phase 9 acceptance criteria met. Asymmetry coverage gap closed (1 spec added), meta-spec at spec/asymmetry/coverage_spec.rb prevents future regressions, playtest run on <DATE> with all blockers fixed. v2 playing-MVP shipped."
```

- [ ] **Step 3: Update issue #1's body to mark v2 playing-MVP shipped**

Read the current body first:

```bash
gh issue view 1 --json body -q .body > /tmp/issue-1-body.md
```

Append the closing note to `/tmp/issue-1-body.md`:

```markdown

---

## v2 playing-MVP shipped

Phase 9 closed on <DATE>. The v2 playing-MVP — sign-in, campaign authoring, end-to-end Anthropic-streamed narration with structural asymmetry, dice/oracle, scene close + audit — is live on `gygaxagain.com`.

- Phase 9 closure: #10
- Playtest log: `docs/superpowers/playtests/<DATE>-phase-9-shake-out.md`
- Polish follow-up parent: #<followup-parent>

Future phases (faction tick, revelations, threads, modules, intake, audit hardening) will be brainstormed and planned individually per the per-phase loop in the Phase 0 roadmap.
```

Then push the updated body:

```bash
gh issue edit 1 --body-file /tmp/issue-1-body.md
```

- [ ] **Step 4: Close issue #1**

Run:

```bash
gh issue close 1 --comment "v2 playing-MVP shipped. Phase 9 (#10) closed; first end-to-end production session played; structural asymmetry verified by tests and by spot-check of llm_calls.prompt_payload. Post-MVP phases (faction tick, revelations, threads, modules, intake, audit hardening) will be filed and worked individually when prioritized."
```

- [ ] **Step 5: Final verification**

Run: `gh issue list --state open --label v2,phase`

Expected: no v2 phase issues remain open. The polish-followup parent and any deferred sub-issues remain open under their own labels, but no `phase` label issue is open.

---

## Self-Review Notes

After writing this plan, I checked it against the (corrected) spec:

**Spec coverage:** every "Phase close criteria" checkbox in the spec maps to at least one task:
- 13 Group-A regression check → Task 8 (full suite green).
- Group-B picker assertion → Task 1.
- Group-C HomeComponent marker + allowlist → Tasks 2 + 3.
- Meta-spec exists + passes + catches regression → Tasks 3–7.
- Player ViewModel + PromptBuilder regression → Task 8.
- Playtest on production → Tasks 9–10.
- Findings log + spot-check llm_calls → Task 10.
- Blocker fixes + polish filed → Tasks 11–12.
- Issue hygiene + #10/#1 closed → Task 13.

**Placeholder scan:** no "TBD" / "implement later" / "similar to" placeholders. Two intentional placeholders — `<DATE>` and `<followup-parent>` — are explicitly called out as values to substitute at execution time. The `bash` commands using `<<'EOF'` heredocs do not interpolate, so the `<...>` markers must be edited by the executor before running.

**Type consistency:** `assert_coverage_for`, `descendants_of`, `spec_file_for`, `EXEMPT_COMPONENTS` are used consistently across Tasks 3–7. The meta-spec describes append in fixed order: ViewModel (Task 4), Component (Task 5), PromptBuilder (Task 6). Expected example counts increment by 1 per task: 1, 2, 3.
