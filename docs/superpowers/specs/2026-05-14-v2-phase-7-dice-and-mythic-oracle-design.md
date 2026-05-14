# v2 Phase 7 — Dice + Mythic oracle service objects

Date: 2026-05-14
Status: Design spec. Drives the writing-plans pass for Phase 7.
Issue: [#8](https://github.com/barriault/gygaxagain/issues/8)
Parent roadmap: [`2026-05-13-v2-phase-0-roadmap-design.md`](2026-05-13-v2-phase-0-roadmap-design.md)
Prior phase: [`2026-05-14-v2-phase-6-play-surface-ui-shell-design.md`](2026-05-14-v2-phase-6-play-surface-ui-shell-design.md)
v1 lineage: `tools/dice/src/dice/parser.py` and `tools/mythic/src/mythic/{fate_chart,events,chaos}.py` at the `v1-final-poc` tag.

## Scope

Two non-LLM mechanical surfaces on the per-scene play page and the per-campaign chaos-factor admin surface. Service objects under `Dice::` and `Mythic::` port v1's tested algorithms to Ruby. The player clicks Roll or Ask; the controller creates an `Event` row scoped to the current scene; a Turbo Stream appends the new event into the scene log and resets the form. Phase 7 does NOT compose the random-event focus/action/subject — that's Phase 13 (post-MVP per the Phase 0 roadmap). Phase 7 records a boolean `random_event_triggered` on the oracle event payload so the existing `Play::Events::OracleQueryComponent` can surface a subtle badge and grow into composition later without a schema change.

## Dependencies

Phase 6 ([#7](https://github.com/barriault/gygaxagain/issues/7)) complete:
- `Scene`, `Event`, and the four event kinds (`narration`, `dice_roll`, `oracle_query`, `scene_transition`) exist with the `events.payload` jsonb column.
- `Play::Scenes::PlayComponent`, `Play::Scenes::LogComponent`, `Play::Events::Component` dispatcher and the four `Play::Events::*Component` already render dice/oracle event records from `payload` keys (`expression`, `result`, `breakdown`, `question`, `answer`, `likelihood`, `chaos`). Phase 7 preserves these keys.
- Admin campaign show page (`Admin::Campaigns::ShowComponent`) exists with a place to host the new chaos-factor panel.
- Phase 5 asymmetry matcher `leak_secrets_of` exists and accepts `String` subjects.

## Acceptance criteria

Verbatim from the GitHub issue:

- `Dice::Roll` service parses expressions like `2d6+3`, `1d20-1`, returns a structured result.
- `Mythic::Oracle` service takes a question + likelihood + chaos factor, returns yes/no/exceptional/random_event.
- Both are surfaced in the play UI; clicking creates an Event, broadcast via Turbo Streams to the scene log.
- Chaos factor is per-campaign state, adjustable from admin.
- Tests cover dice expression edge cases and oracle outcome tables.

## Architectural commitments inherited from Phase 0 / Phase 6

- **ViewComponent for all view composition.** No partials in the new code path.
- **Hotwire (Turbo + Stimulus).** Phase 7 introduces Turbo Stream broadcasts and two new Stimulus controllers. All client-side JavaScript goes through Stimulus controllers — no inline JS, no logic in `application.js` beyond controller registration.
- **Subdomain split.** Play surfaces under `Play::`; admin surfaces under `Admin::`. Phase 7 adds controllers in both namespaces but does not cross-import components.
- **Default-deny auth.** All new controllers inherit `before_action :authenticate_user!` from `ApplicationController`. No skips.
- **Tenant scoping** via `current_user.campaigns.find(params[:campaign_id]).scenes.find(params[:scene_id])`. Cross-user access returns 404.
- **Asymmetry guard on player-facing components.** Every new `Play::*` component spec includes one `not_to leak_secrets_of(faction, npc)` example. Phase 7 components don't reach for Faction/Npc data, so the guard is preventive — it catches future regressions where a sidebar might surface secrets via the AR graph.

## Open decisions resolved in this spec

### Random event in Phase 7 = trigger flag only

**Decision:** `Mythic::Oracle::Result` includes a `random_event_triggered` boolean. It does NOT include focus / action / subject. Composition of those Meaning-Table samples is Phase 13 work per the Phase 0 roadmap ("Mythic random-event composition (v1 Phase 2d equivalent)").

Rationale: The Phase 0 roadmap explicitly defers Mythic random-event composition to post-MVP. Phase 7 includes the trigger-detection logic (which is a single rule on the d100 roll and chaos factor) and exposes it as a flag so the UI can grow into composition later without a schema migration.

The acceptance criterion phrasing ("returns yes/no/exceptional/random_event") is satisfied: `outcome ∈ {:exceptional_yes, :yes, :no, :exceptional_no}` covers the four oracle outcomes, and `random_event_triggered: true|false` is the parallel signal that the rulebook describes (Mythic 2e p.35).

### Port v1's full dice grammar, including `kh` / `kl`

**Decision:** Port v1's `tools/dice/src/dice/parser.py` grammar verbatim to Ruby, including the keep-highest (`khN`) and keep-lowest (`klN`) modifiers.

Grammar:
```
expression := term ( ('+' | '-') term )*
term       := dice | constant
dice       := <count>d<sides>[k(h|l)<n>]
constant   := <integer>
```

Examples accepted: `2d6+3`, `1d20-1`, `4d6kh3`, `2d20kl1+5`, `1d6+1d8`, `+5`.

Rationale: `kh/kl` is essentially free to port (one branch in the term-evaluator), and immediately useful for D&D 5e ability scores (`4d6kh3`) and advantage / disadvantage idioms (`2d20kh1` / `2d20kl1`). Confining the grammar to "minimal" would force re-introducing this in the very next dice-touching phase.

Out of scope for Phase 7's grammar: exploding dice (`1d6!`), rerolls (`1d20r1`), threshold tests (`5d10>=7`). Add when concretely needed.

### Chaos factor lives on `campaigns.chaos_factor`

**Decision:** Add `chaos_factor :integer, default: 5, null: false` directly to the `campaigns` table. Validate `inclusion: { in: 1..9 }` on the model.

Alternatives considered:
- Separate `campaign_settings` table (one-to-one with campaign). More flexible but the cost is a join and a second model for what is currently one scalar. Revisit when the campaign has 3+ settings.
- Per-scene chaos factor. Mythic 2e treats chaos as a session-level state, not per-scene. Phase 0 commits to per-campaign; Phase 7 honors that.

Existing campaigns backfill to `5` (Mythic 2e default starting chaos).

### Chaos factor admin UI — inline panel on campaign show page

**Decision:** `Admin::Campaigns::ChaosFactorComponent` renders inline on the existing `Admin::Campaigns::ShowComponent` page (no new admin route). Displays the current value with `−` and `+` buttons that POST to `Admin::ChaosFactorsController#update` (a singleton resource nested under campaigns). Server clamps to 1..9; buttons visually disable at the boundary.

Alternatives considered:
- A field on the campaign edit form. Higher friction (open form → change → save). The chaos factor is intentionally mutable between scenes; making it a one-click adjustment matches the play feel.
- A dedicated admin sub-page. Overkill for one integer.

### Play UI — two side-by-side cards in `Play::Scenes::InputDockComponent`

**Decision:** A new `Play::Scenes::InputDockComponent` renders below the existing `Play::Scenes::LogComponent` inside `Play::Scenes::PlayComponent`. The dock contains two cards (side-by-side on `md:` breakpoint and above, stacked below): `Play::Dice::FormComponent` and `Play::Oracle::FormComponent`.

- `Play::Dice::FormComponent` — an expression text input, a Roll submit, and four quick-roll chips (`d20`, `d100`, `2d6`, `4d6kh3`) that fill the input on click.
- `Play::Oracle::FormComponent` — a question text input, a likelihood `select` with the 9 values (default `50_50`), a small "chaos N" label rendered from the campaign, and an Ask submit.

Alternatives considered:
- Tabbed dock (dice tab + oracle tab). Adds a tab-controller Stimulus, hides one surface behind a click, and the play page has horizontal room.
- Floating action buttons that open modals. More UI ceremony per roll; modals harm flow.

Side-by-side cards have no hidden state, no Stimulus state machine, and read naturally as "what would you like to do next."

### New Stimulus controllers in Phase 7

**Decision:** Two new Stimulus controllers:

- `dice_form_controller.js` — handles quick-roll-chip clicks (sets the expression input value, optionally submits the form), and clears the input on successful Turbo Stream response.
- `oracle_form_controller.js` — clears the question input on successful response. Default likelihood remains selected across submissions (useful when asking a sequence of questions at the same likelihood).

Phase 6's "no new Stimulus controllers" was scoped to Phase 6. Phase 7 brings in Turbo Streams (a Phase-7 requirement per the acceptance criterion) and these two minimal controllers ride along.

Auto-scroll-to-bottom on new event arrival is deferred to Phase 8 (per Phase 6's future-direction note). If it proves jarring in playtesting between Phase 7 and Phase 8, a tiny `scene_log_scroll_controller.js` can be added without restructuring.

### Turbo Stream targets

**Decision:** `Play::Scenes::LogComponent` wraps its events list in a `<turbo-frame>` with id `dom_id(scene, :log)` (e.g. `scene_log_42`). The empty-state placeholder is rendered as its own element with id `dom_id(scene, :log_empty)` so it can be removed in a paired stream when the first event lands.

On a successful Roll or Ask:

```ruby
turbo_stream.append(dom_id(scene, :log), Play::Events::Component.for(event).new(event:))
turbo_stream.remove(dom_id(scene, :log_empty))      # no-op if not present
turbo_stream.update(form_target, Play::Dice::FormComponent.new(scene:, errors: {})) # or oracle
```

The third stream replaces the form with a fresh, error-free copy (handles both reset and any error-state cleanup). The form's Stimulus controller may also locally clear the input for instant feedback before the stream lands.

### Event payload schemas (additive to Phase 6)

The Phase 6 components already read these keys; Phase 7 preserves them and adds new ones.

**`dice_roll` payload** (unchanged keys):
```json
{
  "expression": "2d6+3",
  "result": 11,
  "breakdown": ["2d6 = [4, 5] = 9", "+3"]
}
```

Phase 7 also includes a `rolls` array of per-die integers for transparency. The current `DiceRollComponent` does not read this; future UI can.

```json
{
  "expression": "2d6+3",
  "result": 11,
  "breakdown": ["2d6 = [4, 5] = 9", "+3"],
  "rolls": [[4, 5], []]
}
```

**`oracle_query` payload** (Phase 6 keys preserved, new keys additive):
```json
{
  "question": "Does the door open?",
  "answer": "Yes",
  "likelihood": "50_50",
  "chaos": 5,
  "outcome": "yes",
  "roll": 32,
  "random_event_triggered": false
}
```

- `answer` is the humanized outcome string (`"Exceptional Yes"`, `"Yes"`, `"No"`, `"Exceptional No"`) so Phase 6's `OracleQueryComponent#answer` keeps working.
- `outcome` is the raw symbol-as-string (`"exceptional_yes"`, `"yes"`, `"no"`, `"exceptional_no"`) for programmatic consumers.
- `roll` is the d100 result (1..100) for transparency and so the random-event-trigger condition is reproducible from the payload.
- `random_event_triggered` is the boolean signal.

### Oracle event component grows a subtle "random event" badge

**Decision:** `Play::Events::OracleQueryComponent` renders an inline badge ("✦ random event") when `event.payload["random_event_triggered"]` is true. The badge is non-interactive in Phase 7. Phase 13 will wire it to a composition affordance.

### Validation and error UX

- Dice expression empty → form re-renders with an inline error ("enter a dice expression").
- Dice expression unparseable → form re-renders with the parser's message inline.
- Oracle question empty → form re-renders with an inline error ("enter a question").
- Oracle likelihood missing → defaults to `50_50` server-side (no error; defaults match Mythic 2e).
- All errors return HTTP `422 :unprocessable_content` with the form re-rendered via Turbo Stream `replace` on the form's `dom_id`. The scene log is not appended to on error.

### Strong params

- `dice_roll`: `params.require(:dice_roll).permit(:expression)`.
- `oracle_query`: `params.require(:oracle_query).permit(:question, :likelihood)`.
- `chaos_factor`: `params.permit(:direction)` where `direction ∈ {"up", "down"}`. Server enforces clamp to 1..9.

## Service object design

### `Dice::Parser`

`app/services/dice/parser.rb`. Pure parser, no rolling. Returns either a list of `Dice::Parser::Term` objects (`DiceTerm` or `ConstantTerm`) or raises `Dice::ParseError` on malformed input.

```ruby
module Dice
  class ParseError < StandardError; end

  module Parser
    DiceTerm     = Data.define(:count, :sides, :sign, :keep)  # keep: nil | [:h|:l, n]
    ConstantTerm = Data.define(:value, :sign)

    TERM_RE = /
      \s*
      (?<sign>[+-])?\s*
      (?:
        (?<count>\d+)d(?<sides>\d+)
        (?:k(?<keep>[hl])(?<keep_n>\d+))?
        |
        (?<const>\d+)
      )
    /x

    def self.parse(expression)
      # Ports tools/dice/src/dice/parser.py parse_expression() verbatim.
      # Edge cases:
      # - empty / whitespace-only expression -> Dice::ParseError("empty dice expression")
      # - missing operator between terms (e.g. "1d6 1d8") -> Dice::ParseError
      # - unparseable trailing input -> Dice::ParseError with position
      # - 0d6 / Xd0 -> Dice::ParseError (count and sides must be >= 1)
      # - khN where N >= count -> valid (keeps all dice; matches v1 semantics)
    end
  end
end
```

Sane upper bounds: reject `count > 100` and `sides > 10_000` as `Dice::ParseError`. Prevents pathological inputs while allowing every plausible game expression.

### `Dice::Random`

`app/services/dice/random.rb`. Thin wrapper around `SecureRandom`.

```ruby
module Dice
  module Random
    module_function

    def roll(sides)
      SecureRandom.random_number(sides) + 1
    end

    def with_fixed(values)
      old = method(:roll)
      define_singleton_method(:roll) { |_sides| values.shift }
      yield
    ensure
      define_singleton_method(:roll, &old)
    end
  end
end
```

(Implementation detail: a thread-local fiber-storage variable may be cleaner; the plan settles the exact shape. The contract is `Dice::Random.roll(sides)` and a test-only override.)

### `Dice::Roll`

`app/services/dice/roll.rb`. Public entry point.

```ruby
module Dice
  class Roll
    Result = Data.define(:expression, :total, :breakdown, :rolls)

    def self.call(expression)
      new(expression).call
    end

    def initialize(expression)
      @expression = expression.to_s.strip
    end

    def call
      terms = Dice::Parser.parse(@expression)
      evaluated = terms.map { evaluate(_1) }
      total = evaluated.sum { _1.fetch(:value) }
      breakdown = evaluated.map { _1.fetch(:render) }
      rolls = evaluated.map { _1.fetch(:rolls) }
      Result.new(expression: @expression, total:, breakdown:, rolls:)
    end

    private

    def evaluate(term)
      case term
      when Dice::Parser::ConstantTerm
        { value: term.sign * term.value, render: format_constant(term), rolls: [] }
      when Dice::Parser::DiceTerm
        rolls = Array.new(term.count) { Dice::Random.roll(term.sides) }
        kept, dropped = apply_keep(rolls, term.keep)
        sum = term.sign * kept.sum
        { value: sum, render: format_dice(term, rolls, kept, dropped), rolls: rolls }
      end
    end
    # ... format helpers and apply_keep ported from v1
  end
end
```

Result example for `4d6kh3` rolling [3, 5, 6, 2]:
```ruby
#<Dice::Roll::Result
  expression: "4d6kh3",
  total: 14,
  breakdown: ["4d6kh3 = [3, 5, 6, ~~2~~] = 14"],
  rolls: [[3, 5, 6, 2]]>
```

(The breakdown string format is final-pass polish; the plan settles the exact characters used to render kept vs. dropped dice.)

### `Mythic::FateChart`

`app/services/mythic/fate_chart.rb`. Pure data. Transcribes v1's `fate_chart.py` 81-cell table (Mythic GME 2e p.19).

```ruby
module Mythic
  module FateChart
    LIKELIHOODS = %w[
      impossible nearly_impossible very_unlikely unlikely
      50_50
      likely very_likely nearly_certain certain
    ].freeze

    CHAOS_RANGE = (1..9)

    # CHART[[likelihood, chaos]] = [exc_yes_max, yes_max, no_max, exc_no_max]
    CHART = {
      ["certain", 1]         => [10, 50, 90, 100],
      ["certain", 2]         => [13, 65, 93, 100],
      # ... all 81 cells, transcribed from v1
    }.freeze

    def self.bands_for(likelihood:, chaos_factor:)
      CHART.fetch([likelihood, chaos_factor]) do
        raise ArgumentError,
              "no chart cell for likelihood=#{likelihood.inspect} chaos=#{chaos_factor.inspect}"
      end
    end

    def self.outcome_for(roll:, bands:)
      exc_yes_max, yes_max, no_max, _exc_no_max = bands
      return :exceptional_yes if roll <= exc_yes_max
      return :yes             if roll <= yes_max
      return :no              if roll <= no_max
      :exceptional_no
    end
  end
end
```

A spec asserts all 81 cells exist and each returns a 4-tuple satisfying `0 <= a <= b <= c <= d == 100`.

### `Mythic::Random`

`app/services/mythic/random.rb`. Analogous to `Dice::Random`, with `Mythic::Random.d100` and a `with_fixed_d100(values) { ... }` override for tests.

### `Mythic::Oracle`

`app/services/mythic/oracle.rb`. Public entry point.

```ruby
module Mythic
  class Oracle
    Result = Data.define(
      :question, :likelihood, :chaos_factor,
      :roll, :outcome, :random_event_triggered
    )

    def self.call(question:, likelihood:, chaos_factor:)
      bands = Mythic::FateChart.bands_for(likelihood:, chaos_factor:)
      roll = Mythic::Random.d100
      outcome = Mythic::FateChart.outcome_for(roll:, bands:)
      triggered = random_event?(roll:, chaos_factor:)
      Result.new(
        question:, likelihood:, chaos_factor:,
        roll:, outcome:, random_event_triggered: triggered
      )
    end

    def self.random_event?(roll:, chaos_factor:)
      # Mythic 2e p.35: doubled-digit roll (11, 22, ..., 99)
      # whose digit is <= chaos_factor triggers an event.
      return false unless roll.between?(11, 99)
      tens, units = roll.divmod(10)
      tens == units && tens <= chaos_factor
    end
  end
end
```

## File inventory

Every file added or modified, grouped by area.

### Migration

`db/migrate/YYYYMMDDHHMMSS_add_chaos_factor_to_campaigns.rb` — new:

```ruby
class AddChaosFactorToCampaigns < ActiveRecord::Migration[8.0]
  def change
    add_column :campaigns, :chaos_factor, :integer, default: 5, null: false
  end
end
```

`Campaign` model gains: `validates :chaos_factor, presence: true, inclusion: { in: 1..9 }`.

### Routes

`config/routes/play.rb` — modified:

```ruby
scope module: "play" do
  resources :campaigns, only: [:index] do
    member { get :play }
    resources :scenes, only: [] do
      member { get :play }
      resources :dice_rolls,     only: [:create]
      resources :oracle_queries, only: [:create]
    end
  end
end
```

`config/routes/admin.rb` — modified:

```ruby
scope module: "admin", as: :admin do
  # ...
  resources :campaigns do
    resource :chaos_factor, only: [:update], controller: "chaos_factors"
    resources :scenes do
      member do
        post :move_up
        post :move_down
      end
    end
  end
  # ...
end
```

### Services

- `app/services/dice/parser.rb` — new. Grammar ported from v1.
- `app/services/dice/random.rb` — new. Test-overridable.
- `app/services/dice/roll.rb` — new. Entry point.
- `app/services/dice.rb` — new. Defines `Dice::ParseError`.
- `app/services/mythic/fate_chart.rb` — new. 81-cell table.
- `app/services/mythic/random.rb` — new. Test-overridable d100.
- `app/services/mythic/oracle.rb` — new. Entry point.

### Controllers

`app/controllers/play/dice_rolls_controller.rb` — new:

```ruby
module Play
  class DiceRollsController < ::ApplicationController
    before_action :load_scene

    def create
      expression = params.require(:dice_roll).permit(:expression).fetch(:expression).to_s

      begin
        result = Dice::Roll.call(expression)
      rescue Dice::ParseError => e
        return render turbo_stream: turbo_stream.replace(
          dom_id_for_dice_form,
          Play::Dice::FormComponent.new(scene: @scene, expression:, error: e.message)
        ), status: :unprocessable_content
      end

      event = @scene.events.create!(
        kind: "dice_roll",
        occurred_at: Time.current,
        payload: {
          "expression" => result.expression,
          "result"     => result.total,
          "breakdown"  => result.breakdown,
          "rolls"      => result.rolls
        }
      )

      respond_to do |f|
        f.turbo_stream { render turbo_stream: stream_event_and_reset_dice(event) }
        f.html { redirect_to play_campaign_scene_path(@scene.campaign, @scene) }
      end
    end

    private

    def load_scene
      @scene = current_user.campaigns.find(params[:campaign_id]).scenes.find(params[:scene_id])
    end

    # ... helpers for dom_ids and the multi-stream response
  end
end
```

`app/controllers/play/oracle_queries_controller.rb` — new. Analogous shape:

```ruby
module Play
  class OracleQueriesController < ::ApplicationController
    before_action :load_scene

    def create
      attrs = params.require(:oracle_query).permit(:question, :likelihood)
      question = attrs.fetch(:question, "").to_s.strip
      likelihood = attrs.fetch(:likelihood, "50_50").to_s

      if question.blank?
        return render turbo_stream: turbo_stream.replace(
          dom_id_for_oracle_form,
          Play::Oracle::FormComponent.new(scene: @scene, question:, likelihood:,
                                          error: "enter a question")
        ), status: :unprocessable_content
      end

      result = Mythic::Oracle.call(
        question:, likelihood:,
        chaos_factor: @scene.campaign.chaos_factor
      )

      event = @scene.events.create!(
        kind: "oracle_query",
        occurred_at: Time.current,
        payload: {
          "question"               => result.question,
          "answer"                 => result.outcome.to_s.humanize,
          "outcome"                => result.outcome.to_s,
          "likelihood"             => result.likelihood,
          "chaos"                  => result.chaos_factor,
          "roll"                   => result.roll,
          "random_event_triggered" => result.random_event_triggered
        }
      )

      respond_to do |f|
        f.turbo_stream { render turbo_stream: stream_event_and_reset_oracle(event) }
        f.html { redirect_to play_campaign_scene_path(@scene.campaign, @scene) }
      end
    end

    # ... load_scene + helpers
  end
end
```

`app/controllers/admin/chaos_factors_controller.rb` — new:

```ruby
module Admin
  class ChaosFactorsController < Admin::ApplicationController
    before_action :load_campaign

    def update
      delta = case params[:direction]
              when "up"   then 1
              when "down" then -1
              else 0
              end
      new_value = (@campaign.chaos_factor + delta).clamp(1, 9)
      @campaign.update!(chaos_factor: new_value)
      redirect_to admin_campaign_path(@campaign),
                  notice: "Chaos factor set to #{new_value}."
    end

    private

    def load_campaign
      @campaign = current_user.campaigns.find(params[:campaign_id])
    end
  end
end
```

### Play-side components

`app/components/play/scenes/play_component.{rb,html.erb}` — modified to render `Play::Scenes::InputDockComponent` below the log. The reserved "right-pane tabs" comment from Phase 6 stays as-is.

`app/components/play/scenes/log_component.{rb,html.erb}` — modified to wrap the events list in a `<turbo-frame id="<%= dom_id(scene, :log) %>">` and render the empty-state placeholder with id `dom_id(scene, :log_empty)`.

`app/components/play/scenes/input_dock_component.{rb,html.erb}` — new. Receives `scene:`. Renders two cards side-by-side at `md:` and above:
```erb
<div class="grid gap-4 mt-8 md:grid-cols-2">
  <%= render Play::Dice::FormComponent.new(scene: scene) %>
  <%= render Play::Oracle::FormComponent.new(scene: scene) %>
</div>
```

`app/components/play/dice/form_component.{rb,html.erb}` — new. Receives `scene:`, optional `expression:` (sticky on error), optional `error:`. Renders:
- Header "Roll dice".
- Expression input with `name="dice_roll[expression]"`, prefilled if sticky.
- Inline error if present.
- Submit button "Roll".
- Four quick-roll chip buttons (`d20`, `d100`, `2d6`, `4d6kh3`). Clicking sets the expression input value (via the Stimulus controller) and submits.
- `data-controller="dice-form"`, `data-action="submit->dice-form#onSubmit"`, chips have `data-action="click->dice-form#useChip"` and `data-expression="..."`.

The form posts via Turbo (default for Rails 7+ form helpers) to `play_campaign_scene_dice_rolls_path(scene.campaign, scene)`.

`app/components/play/oracle/form_component.{rb,html.erb}` — new. Receives `scene:`, optional `question:` (sticky on error), optional `likelihood:` (defaults `50_50`), optional `error:`. Renders:
- Header "Ask the oracle".
- Question text input with `name="oracle_query[question]"`.
- Likelihood `<select>` with the 9 options labeled in title case ("Impossible", "Nearly impossible", ..., "Certain"), `name="oracle_query[likelihood]"`.
- Small "chaos N" indicator from `scene.campaign.chaos_factor`.
- Inline error if present.
- Submit "Ask".
- `data-controller="oracle-form"`, `data-action="submit->oracle-form#onSubmit"`.

`app/components/play/events/oracle_query_component.{rb,html.erb}` — modified. Adds a subtle `✦ random event` badge when `payload["random_event_triggered"]` is true. The existing chaos/likelihood line is unchanged.

### Admin-side components

`app/components/admin/campaigns/chaos_factor_component.{rb,html.erb}` — new. Receives `campaign:`. Renders a labeled panel: "Chaos factor", current value, `−` and `+` buttons each posting to `admin_campaign_chaos_factor_path(campaign)` with `direction=up|down`. Buttons disabled at boundaries (`disabled` attribute on `<button>` when at 1 or 9).

`app/components/admin/campaigns/show_component.{rb,html.erb}` — modified to render the chaos-factor component near the top of the campaign show page (above the scenes list).

### Stimulus controllers

`app/javascript/controllers/dice_form_controller.js` — new. Targets: `expression` (input element). Actions: `useChip(event)` (reads `event.params.expression`, sets input value, requests form submit), `onSubmit(event)` (no-op pre-submit; Turbo handles the rest). Clear the input when the form's Turbo Stream response replaces it with a fresh component instance (handled implicitly because the streamed component re-renders without the sticky value).

`app/javascript/controllers/oracle_form_controller.js` — new. Targets: `question` (input). Actions: `onSubmit(event)` (no-op pre-submit). Cleared via Turbo Stream replacement as above.

`app/javascript/application.js` — modified to register the two new controllers alongside the existing `FlashController`.

### Lookbook previews

Mirror the component tree under `spec/components/previews/`:

- `play/dice/form_component_preview.rb` — `default`, `with_sticky_value`, `with_error`.
- `play/oracle/form_component_preview.rb` — `default`, `with_sticky_value`, `with_error`, `with_high_chaos` (campaign chaos = 9 indicator).
- `play/scenes/input_dock_component_preview.rb` — `default`.
- `play/events/oracle_query_component_preview.rb` — extended with a `random_event_triggered` example.
- `admin/campaigns/chaos_factor_component_preview.rb` — `mid_range`, `at_minimum` (− disabled), `at_maximum` (+ disabled).

### Specs

**Service specs** (under `spec/services/`):

- `spec/services/dice/parser_spec.rb` — grammar coverage. Cases: `2d6+3`, `1d20-1`, `4d6kh3`, `2d20kl1+5`, `1d6+1d8`, `+5`, leading whitespace, internal whitespace, lowercase `d`, optional sign on first term. Failure cases: empty, whitespace-only, missing operator (`1d6 1d8`), trailing junk, `0d6`, `1d0`, `5d6kh0`, count > 100, sides > 10000.
- `spec/services/dice/roll_spec.rb` — deterministic via `Dice::Random.with_fixed([...])`. Cases: simple add, simple subtract, multi-term, `kh` keeps highest, `kl` keeps lowest, `kh > count` keeps all, constant-only expression, negative leading constant, breakdown rendering shape.
- `spec/services/mythic/fate_chart_spec.rb` — all 81 cells exist; each cell is a 4-tuple `(a, b, c, d)` with `0 <= a <= b <= c <= d == 100`; `outcome_for` returns the right band for boundary rolls of representative cells; unknown `(likelihood, chaos)` raises `ArgumentError`.
- `spec/services/mythic/oracle_spec.rb` — deterministic via `Mythic::Random.with_fixed_d100`. For a representative cell, each band's roll produces the expected outcome. Random-event trigger: for every chaos 1..9, rolls 11, 22, ..., 99 trigger if and only if the leading digit ≤ chaos. Non-doubled rolls (12, 25, 47, etc.) never trigger.

**Model spec** (modified):

- `spec/models/campaign_spec.rb` — adds: `chaos_factor` default 5; invalid below 1 or above 9; presence required.

**Request specs** (under `spec/requests/`):

- `spec/requests/play/dice_rolls_spec.rb` — happy path creates a `dice_roll` event with correct payload keys (`expression`, `result`, `breakdown`, `rolls`); deterministic via `Dice::Random.with_fixed`; unparseable expression returns 422 and does not create an event; cross-user campaign access returns 404; cross-user scene access returns 404; Turbo Stream response includes the expected stream actions.
- `spec/requests/play/oracle_queries_spec.rb` — happy path creates an `oracle_query` event with all payload keys (Phase 6 + Phase 7); deterministic via `Mythic::Random.with_fixed_d100`; blank question returns 422; missing likelihood defaults to `50_50`; random-event-trigger roll sets `random_event_triggered: true` on the event payload; uses the campaign's `chaos_factor` not a query param; cross-user 404 cases.
- `spec/requests/admin/campaigns/chaos_factors_spec.rb` — `direction=up` increments; `direction=down` decrements; clamps at 1 (down) and 9 (up); cross-user 404; redirects to admin campaign show.

**Component specs** (under `spec/components/`):

- `spec/components/play/dice/form_component_spec.rb` — renders inputs and chips; asymmetry guard.
- `spec/components/play/oracle/form_component_spec.rb` — renders inputs, 9 likelihood options, chaos label; asymmetry guard.
- `spec/components/play/scenes/input_dock_component_spec.rb` — renders both form components; asymmetry guard.
- `spec/components/play/events/oracle_query_component_spec.rb` — modified: badge appears when `random_event_triggered: true`; absent otherwise; asymmetry guard already present.
- `spec/components/admin/campaigns/chaos_factor_component_spec.rb` — renders current value; − disabled at 1; + disabled at 9. (Admin → no asymmetry guard.)
- `spec/components/admin/campaigns/show_component_spec.rb` — modified: renders the chaos-factor panel.

**System spec** (under `spec/system/`):

- `spec/system/phase_7_play_mechanics_spec.rb` — sign in → admin: create campaign and a scene → navigate to play subdomain → open scene → roll `1d20` (stubbed via `Dice::Random.with_fixed`) and confirm event appears in the log → ask oracle question at `likely` (stubbed via `Mythic::Random.with_fixed_d100` for a chaos=5 hit and a chaos=5 random-event trigger) and confirm event appears with the badge → switch to admin → bump chaos to 6 via the + button → return to play → confirm the oracle form's "chaos N" label now reads 6.

Driver: rack_test for the parts without JS, Selenium for the Turbo Stream + Stimulus paths. Phase 6's spec helpers handle the subdomain switching; Phase 7 reuses them.

## Asymmetry test pattern

Same pattern as Phase 6, applied to the three new player-facing components (`Play::Dice::FormComponent`, `Play::Oracle::FormComponent`, `Play::Scenes::InputDockComponent`):

```ruby
describe "asymmetry" do
  let(:campaign) { create(:campaign) }
  let(:scene)    { create(:scene, campaign: campaign) }
  let(:faction)  { create(:faction, campaign: campaign) }
  let(:npc)      { create(:npc, campaign: campaign) }

  before do
    create(:faction_secret, faction:, label: "hidden temple", content: "in the swamp")
    create(:npc_secret,     npc:,     label: "true identity", content: "is a doppelganger")
  end

  it "does not leak secrets of related records" do
    rendered = render_inline(described_class.new(scene: scene)).to_s
    expect(rendered).not_to leak_secrets_of(faction, npc)
  end
end
```

These are preventive guards — the components don't reach for faction / NPC data — but they protect against a future "show recent NPCs in the dock" regression.

The `Play::Events::OracleQueryComponent` modification reuses the existing asymmetry guard from Phase 6.

The admin chaos-factor component does NOT get an asymmetry guard (admin is the narrator-side surface; allowed to surface secrets).

## Out of scope / non-goals

- **Random-event focus / action / subject composition.** Phase 13.
- **Mythic threads.** Phase 12.
- **Hidden / DM-only roll visibility.** v1 had `meta/dice-config.md` for this; v2 playing-MVP defers it. All Phase 7 rolls and oracle results are visible in the player-facing event log.
- **Per-character skill rolls** ("roll perception for Alice"). The character sheet model doesn't exist in v2 yet.
- **Auto-scroll-to-bottom on new event.** Phase 8 task (per Phase 6 future-direction note). Phase 7 broadcasts via Turbo Stream `append`; the user can scroll manually for a single phase.
- **Dice grammar beyond `kh/kl`.** No exploding dice, no rerolls, no threshold tests. Add when concretely needed.
- **Roll history / "roll again"** affordances. The scene log IS the history; reissuing a roll means typing it again.
- **Chaos factor analytics** (rate-of-change charts, etc.). Not useful at alpha scale.
- **Chaos factor outside the 1..9 range.** Mythic 2e defines 1..9 and that's the entire fate chart.
- **Multiple-question oracle batching.** One question per Ask click.
- **Custom oracle outcome interpretations.** The component renders the four-band outcome string verbatim.

## Future direction (captured for context, not implemented)

- **Phase 13 Mythic random-event composition.** When the badge becomes interactive, clicking it reveals composed focus / action / subject from the Mythic 2e Meaning Tables, with thread-targeting (Phase 12) for `Move Toward / Away From / Close A Thread` focuses. The Phase 7 payload already carries `roll` and `random_event_triggered`, so Phase 13 only adds composition logic + UI — no schema migration.
- **Phase 12 Mythic threads.** Threads CRUD reaches into the oracle event for thread-focused random events (via stored `roll`).
- **Streaming-narration auto-scroll.** Phase 8's auto-scroll Stimulus controller will also benefit Phase 7's append broadcasts.
- **Per-roll visibility flags.** When `Player::CharacterViewModel` exists in a future phase, the play surface may grow a "hidden" toggle that suppresses the result number on the log (showing only `?`) while logging the value in narrator-side state. Out of scope for v2 playing-MVP.
- **`Dice::Roll` skill modifier integration.** When character sheets exist, the dice form can accept skill name + character, look up the modifier, build the expression server-side. Defers to that phase.

## Notes for the implementation plan

- Services live at `app/services/dice/*.rb` and `app/services/mythic/*.rb`. The Rails 8 default autoload paths include `app/services`. If `config/application.rb` doesn't yet add it, the plan adds the directory and verifies Zeitwerk's expected `app/services/dice/parser.rb` ↔ `Dice::Parser` mapping.
- `Dice::ParseError` lives in `app/services/dice.rb` (a one-line file) so the constant is loadable independently of the parser.
- `Dice::Random.with_fixed` and `Mythic::Random.with_fixed_d100` must be safe to use under parallel test execution. The plan resolves the exact mechanism (thread-local storage vs. Fiber storage vs. module-level mutex).
- The 81-cell `Mythic::FateChart::CHART` should be machine-transcribed from `v1-final-poc:tools/mythic/src/mythic/fate_chart.py` — not retyped by hand. The plan adds a one-shot transcription step (read v1 source, emit Ruby) before the corresponding spec runs.
- `Play::Scenes::LogComponent`'s `dom_id(scene, :log)` becomes the Turbo Stream target. Existing Phase 6 component spec assertions about the rendered HTML need updating to expect the wrapping `<turbo-frame>` and the empty-state's id.
- The `dom_id` for the form components is e.g. `dom_id(scene, :dice_form)` and `dom_id(scene, :oracle_form)`; the form's container element carries this id so a `turbo_stream.replace` finds it.
- `Admin::ChaosFactorsController` uses a `resource :chaos_factor` (singular) under `resources :campaigns`. Rails generates `admin_campaign_chaos_factor_path(campaign)` for the `#update` action via PATCH. The buttons are rendered as `button_to ... method: :patch, params: { direction: "up" }`.
- The `OracleQueryComponent`'s existing asymmetry spec from Phase 6 keeps passing — the modification adds a conditional render branch that doesn't touch the asymmetry surface.
- The system spec asserts the Turbo Stream end state (event in the log) rather than racing the stream — `expect(page).to have_text(...)` with Capybara's default wait handles the async delivery.
- `Admin::ChaosFactorsController` inherits from `Admin::ApplicationController` (the existing admin base used by `Admin::CampaignsController` and `Admin::ScenesController`), so it picks up the admin layout and any cross-admin `before_action`s without further wiring.
- The system spec is the first one in v2 that requires JavaScript execution — Phase 6's spec used rack_test. The plan adds Selenium (or `cuprite`) driver setup: Gemfile entry, `Capybara.javascript_driver` config in `spec/rails_helper.rb` or a dedicated `spec/support/capybara.rb`, and the `js: true` (or `driver: :selenium_headless`) metadata on the Phase 7 system example. RuboCop / Brakeman / erb_lint are unaffected.
