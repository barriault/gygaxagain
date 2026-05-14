# v2 Phase 7 — Dice + Mythic oracle service objects: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the two non-LLM mechanical surfaces — `Dice::Roll` and `Mythic::Oracle` service objects ported from v1, surfaced in the play UI as a footer input dock with Turbo-Stream-broadcast events, plus a per-campaign `chaos_factor` admin panel. End state: a signed-in user can roll dice and ask oracle questions from a scene's play page, see each as a new event in the live-updating scene log; admin can adjust chaos factor between scenes; all service edge cases and outcome tables are covered by tests.

**Architecture:** Service objects under `app/services/dice/` and `app/services/mythic/` (plain Ruby, no Rails deps). Stateless `*::Random` wrappers around `SecureRandom` provide test override hooks. `Mythic::FateChart` transcribes v1's 81-cell table (Mythic GME 2e p.19) verbatim. Two new `Play::*Controller#create` actions create `Event` rows scoped via `current_user.campaigns.find(...).scenes.find(...)`, then render a multi-action `turbo_stream` response that appends the new event component into `<turbo-frame id="scene_log_#{id}">`, removes the empty-state placeholder if present, and replaces the form to clear it. Two thin Stimulus controllers (`dice-form`, `oracle-form`) handle quick-roll chip clicks. Phase 7 wires Selenium-headless-Chrome into Capybara for the first JS-bearing system spec in v2.

**Tech Stack:** Rails 8.1 · ViewComponent · Turbo Streams · Stimulus · Tailwind CSS · Lookbook · RSpec · Capybara + `selenium-webdriver` · factory_bot · shoulda-matchers · `SecureRandom`.

**Spec:** [`docs/superpowers/specs/2026-05-14-v2-phase-7-dice-and-mythic-oracle-design.md`](../specs/2026-05-14-v2-phase-7-dice-and-mythic-oracle-design.md).

**Issue:** [#8](https://github.com/barriault/gygaxagain/issues/8).

---

## File structure

**Schema (Task 1):**
- `db/migrate/YYYYMMDDHHMMSS_add_chaos_factor_to_campaigns.rb` — new
- `app/models/campaign.rb` — modified (validation)
- `spec/models/campaign_spec.rb` — modified

**Dice services (Tasks 2-6):**
- `app/services/dice.rb` — new (module + ParseError)
- `app/services/dice/parser.rb` — new
- `app/services/dice/random.rb` — new
- `app/services/dice/roll.rb` — new
- `spec/services/dice/parser_spec.rb` — new
- `spec/services/dice/random_spec.rb` — new
- `spec/services/dice/roll_spec.rb` — new

**Mythic services (Tasks 7-10):**
- `app/services/mythic.rb` — new (module)
- `app/services/mythic/fate_chart.rb` — new (81-cell CHART + outcome helpers)
- `app/services/mythic/random.rb` — new
- `app/services/mythic/oracle.rb` — new
- `spec/services/mythic/fate_chart_spec.rb` — new
- `spec/services/mythic/random_spec.rb` — new
- `spec/services/mythic/oracle_spec.rb` — new

**Routes (Task 11):**
- `config/routes/play.rb` — modified (nested `dice_rolls`, `oracle_queries`)
- `config/routes/admin.rb` — modified (nested singleton `chaos_factor`)

**Admin chaos UI (Tasks 12-14):**
- `app/controllers/admin/chaos_factors_controller.rb` — new
- `app/components/admin/campaigns/chaos_factor_component.{rb,html.erb}` — new
- `app/components/admin/campaigns/show_component.html.erb` — modified (render the panel)
- `spec/requests/admin/chaos_factors_spec.rb` — new
- `spec/components/admin/campaigns/chaos_factor_component_spec.rb` — new

**Play UI form components (Tasks 15-18):**
- `app/components/play/dice/form_component.{rb,html.erb}` — new
- `app/components/play/oracle/form_component.{rb,html.erb}` — new
- `app/components/play/scenes/input_dock_component.{rb,html.erb}` — new
- `spec/components/play/dice/form_component_spec.rb` — new
- `spec/components/play/oracle/form_component_spec.rb` — new
- `spec/components/play/scenes/input_dock_component_spec.rb` — new

**Scene log + play surface (Tasks 19-20):**
- `app/components/play/scenes/log_component.{rb,html.erb}` — modified (turbo-frame wrap + empty-state id)
- `app/components/play/scenes/play_component.html.erb` — modified (render the input dock)
- `spec/components/play/scenes/log_component_spec.rb` — modified (assert frame + empty-state id)
- `spec/components/play/scenes/play_component_spec.rb` — modified (assert the dock renders)

**Play controllers (Tasks 21-22):**
- `app/controllers/play/dice_rolls_controller.rb` — new
- `app/controllers/play/oracle_queries_controller.rb` — new
- `spec/requests/play/dice_rolls_spec.rb` — new
- `spec/requests/play/oracle_queries_spec.rb` — new

**Oracle event component growth (Task 23):**
- `app/components/play/events/oracle_query_component.{rb,html.erb}` — modified (random-event badge)
- `spec/components/play/events/oracle_query_component_spec.rb` — modified

**Stimulus controllers (Tasks 24-25):**
- `app/javascript/controllers/dice_form_controller.js` — new
- `app/javascript/controllers/oracle_form_controller.js` — new
- `app/javascript/application.js` — modified (register both)

**Capybara JS driver + system spec (Tasks 26-27):**
- `Gemfile` — modified (add `selenium-webdriver` to `:test`)
- `Gemfile.lock` — regenerated
- `spec/support/capybara.rb` — modified (driver registration + javascript_driver)
- `spec/system/phase_7_play_mechanics_spec.rb` — new

**Lookbook previews (Task 28):**
- `spec/components/previews/play/dice/form_component_preview.rb` — new
- `spec/components/previews/play/oracle/form_component_preview.rb` — new
- `spec/components/previews/play/scenes/input_dock_component_preview.rb` — new
- `spec/components/previews/play/events/oracle_query_component_preview.rb` — modified (add random-event example)
- `spec/components/previews/admin/campaigns/chaos_factor_component_preview.rb` — new

**Final polish (Task 29):**
- RuboCop, erb_lint, annotaterb refresh

---

## Sequencing notes

- Stages run roughly: schema → pure Ruby services (no Rails) → routes → admin (simpler, no Turbo) → play form components → log/play surface mods → play controllers → oracle badge → Stimulus + Selenium + system spec → previews → polish.
- Each task is one feature slice (TDD: failing test → impl → green → commit). Where a task touches multiple files (e.g., a component's `.rb` + `.html.erb` + spec), all are part of the same commit.
- Run only the affected spec file in each step. The system spec (Task 27) is the only step that runs the full suite at the end.
- Use exact paths and exact commands. The branch is `main` (Phase 0/Phase 6 convention: PRs back to `main`).

---

## Task 1: Add `chaos_factor` to Campaign

**Files:**
- Create: `db/migrate/YYYYMMDDHHMMSS_add_chaos_factor_to_campaigns.rb`
- Modify: `app/models/campaign.rb`
- Modify: `spec/models/campaign_spec.rb`

- [ ] **Step 1.1: Write the failing model spec**

Add to `spec/models/campaign_spec.rb` (inside the existing top-level `RSpec.describe Campaign do ... end` block, alongside the existing validations group):

```ruby
describe "chaos_factor" do
  let(:user) { create(:user) }

  it "defaults to 5 on a new campaign" do
    campaign = Campaign.new(name: "C", user: user)
    expect(campaign.chaos_factor).to eq(5)
  end

  it "is valid for values 1..9" do
    (1..9).each do |value|
      campaign = build(:campaign, chaos_factor: value)
      expect(campaign).to be_valid, "expected chaos_factor=#{value} to be valid"
    end
  end

  it "is invalid below 1" do
    campaign = build(:campaign, chaos_factor: 0)
    expect(campaign).not_to be_valid
    expect(campaign.errors[:chaos_factor]).to be_present
  end

  it "is invalid above 9" do
    campaign = build(:campaign, chaos_factor: 10)
    expect(campaign).not_to be_valid
    expect(campaign.errors[:chaos_factor]).to be_present
  end

  it "is invalid when nil" do
    campaign = build(:campaign, chaos_factor: nil)
    expect(campaign).not_to be_valid
  end
end
```

- [ ] **Step 1.2: Run the spec and confirm it fails**

```
bundle exec rspec spec/models/campaign_spec.rb -e "chaos_factor"
```

Expected: failures complaining about `undefined method 'chaos_factor'` or that the attribute does not exist.

- [ ] **Step 1.3: Generate the migration**

```
bin/rails g migration AddChaosFactorToCampaigns chaos_factor:integer
```

This produces a file at `db/migrate/<timestamp>_add_chaos_factor_to_campaigns.rb`.

- [ ] **Step 1.4: Edit the migration to set default and not-null**

Replace the generated file's body with:

```ruby
class AddChaosFactorToCampaigns < ActiveRecord::Migration[8.1]
  def change
    add_column :campaigns, :chaos_factor, :integer, default: 5, null: false
  end
end
```

- [ ] **Step 1.5: Run the migration in dev and test**

```
bin/rails db:migrate
RAILS_ENV=test bin/rails db:migrate
```

- [ ] **Step 1.6: Add the validation to the Campaign model**

Edit `app/models/campaign.rb`. Inside the existing class body (alongside the `validates :name, ...` line), add:

```ruby
validates :chaos_factor, presence: true,
                         numericality: { only_integer: true,
                                         greater_than_or_equal_to: 1,
                                         less_than_or_equal_to: 9 }
```

- [ ] **Step 1.7: Refresh the model annotation**

```
bundle exec annotaterb models
```

This rewrites the `# == Schema Information` block at the top of `app/models/campaign.rb` to include the new column. The factory file (`spec/factories/campaigns.rb`) also gets a refreshed annotation — that's expected.

- [ ] **Step 1.8: Run the spec and confirm it passes**

```
bundle exec rspec spec/models/campaign_spec.rb -e "chaos_factor"
```

Expected: 5 examples, 0 failures.

- [ ] **Step 1.9: Commit**

```
git add db/migrate/*_add_chaos_factor_to_campaigns.rb db/schema.rb app/models/campaign.rb spec/factories/campaigns.rb spec/models/campaign_spec.rb
git commit -m "Add chaos_factor (1..9, default 5) to Campaign (Phase 7.1)"
```

---

## Task 2: Define `Dice::ParseError` and the `Dice` module

**Files:**
- Create: `app/services/dice.rb`

- [ ] **Step 2.1: Create the module file**

Write `app/services/dice.rb`:

```ruby
module Dice
  class ParseError < StandardError; end
end
```

(No spec for this task — `Dice::ParseError` is exercised by the parser spec in Task 3.)

- [ ] **Step 2.2: Sanity-check autoload**

```
bin/rails runner 'puts Dice::ParseError'
```

Expected output: `Dice::ParseError`.

If autoload fails, check that `app/services` exists (Rails 8 Zeitwerk autoloads any directory under `app/` automatically; no `config/application.rb` change is required).

- [ ] **Step 2.3: Commit**

```
git add app/services/dice.rb
git commit -m "Add Dice module and Dice::ParseError (Phase 7.2)"
```

---

## Task 3: Implement `Dice::Parser`

The parser is a verbatim Ruby port of v1's `tools/dice/src/dice/parser.py`. Grammar:

```
expression := term ( ('+' | '-') term )*
term       := dice | constant
dice       := <count>d<sides>[k(h|l)<n>]
constant   := <integer>
```

Plus Phase 7 sanity bounds (`count <= 100`, `sides <= 10_000`, `count >= 1`, `sides >= 1`).

**Files:**
- Create: `app/services/dice/parser.rb`
- Create: `spec/services/dice/parser_spec.rb`

- [ ] **Step 3.1: Write the parser spec**

Create `spec/services/dice/parser_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Dice::Parser do
  describe ".parse" do
    it "parses a single dice term" do
      result = described_class.parse("2d6")
      expect(result.length).to eq(1)
      term = result.first
      expect(term).to be_a(Dice::Parser::DiceTerm)
      expect(term.count).to eq(2)
      expect(term.sides).to eq(6)
      expect(term.sign).to eq(1)
      expect(term.keep).to be_nil
    end

    it "parses a dice term plus a constant" do
      result = described_class.parse("2d6+3")
      expect(result.length).to eq(2)
      expect(result[0]).to be_a(Dice::Parser::DiceTerm)
      expect(result[1]).to be_a(Dice::Parser::ConstantTerm)
      expect(result[1].value).to eq(3)
      expect(result[1].sign).to eq(1)
    end

    it "parses subtraction" do
      result = described_class.parse("1d20-1")
      expect(result.length).to eq(2)
      expect(result[1].sign).to eq(-1)
      expect(result[1].value).to eq(1)
    end

    it "parses keep-highest" do
      result = described_class.parse("4d6kh3")
      term = result.first
      expect(term.count).to eq(4)
      expect(term.sides).to eq(6)
      expect(term.keep).to eq([:h, 3])
    end

    it "parses keep-lowest" do
      result = described_class.parse("2d20kl1")
      term = result.first
      expect(term.keep).to eq([:l, 1])
    end

    it "parses keep-highest with a trailing constant" do
      result = described_class.parse("4d6kh3+2")
      expect(result.length).to eq(2)
      expect(result[0].keep).to eq([:h, 3])
      expect(result[1].value).to eq(2)
    end

    it "parses multiple dice terms" do
      result = described_class.parse("1d6+1d8")
      expect(result.length).to eq(2)
      expect(result[0]).to be_a(Dice::Parser::DiceTerm)
      expect(result[1]).to be_a(Dice::Parser::DiceTerm)
      expect(result[0].sides).to eq(6)
      expect(result[1].sides).to eq(8)
    end

    it "parses a leading negative" do
      result = described_class.parse("-1d6+5")
      expect(result[0].sign).to eq(-1)
      expect(result[1].sign).to eq(1)
    end

    it "parses a constant-only expression" do
      result = described_class.parse("+5")
      expect(result).to eq([Dice::Parser::ConstantTerm.new(value: 5, sign: 1)])
    end

    it "tolerates whitespace" do
      result = described_class.parse("  2d6 + 3 ")
      expect(result.length).to eq(2)
      expect(result[1].value).to eq(3)
    end

    describe "failure cases" do
      it "raises on empty input" do
        expect { described_class.parse("") }.to raise_error(Dice::ParseError, /empty/i)
      end

      it "raises on whitespace-only input" do
        expect { described_class.parse("   ") }.to raise_error(Dice::ParseError, /empty/i)
      end

      it "raises on missing operator between terms" do
        expect { described_class.parse("1d6 1d8") }.to raise_error(Dice::ParseError, /missing operator|unparseable/i)
      end

      it "raises on unparseable trailing input" do
        expect { described_class.parse("1d6+wat") }.to raise_error(Dice::ParseError)
      end

      it "raises on 0d6 (zero count)" do
        expect { described_class.parse("0d6") }.to raise_error(Dice::ParseError, /count/i)
      end

      it "raises on 1d0 (zero sides)" do
        expect { described_class.parse("1d0") }.to raise_error(Dice::ParseError, /sides/i)
      end

      it "raises on count above 100" do
        expect { described_class.parse("101d6") }.to raise_error(Dice::ParseError, /count/i)
      end

      it "raises on sides above 10_000" do
        expect { described_class.parse("1d10001") }.to raise_error(Dice::ParseError, /sides/i)
      end

      it "raises on kh0 (zero keep count)" do
        expect { described_class.parse("4d6kh0") }.to raise_error(Dice::ParseError, /keep/i)
      end
    end
  end
end
```

- [ ] **Step 3.2: Run the spec and confirm it fails**

```
bundle exec rspec spec/services/dice/parser_spec.rb
```

Expected: all examples fail with `uninitialized constant Dice::Parser`.

- [ ] **Step 3.3: Implement the parser**

Create `app/services/dice/parser.rb`:

```ruby
module Dice
  module Parser
    DiceTerm     = Data.define(:count, :sides, :sign, :keep)
    ConstantTerm = Data.define(:value, :sign)

    MAX_COUNT = 100
    MAX_SIDES = 10_000

    TERM_RE = /
      \A
      \s*
      (?<sign>[+-])?\s*
      (?:
        (?<count>\d+)d(?<sides>\d+)
        (?:k(?<keep>[hl])(?<keep_n>\d+))?
        |
        (?<const>\d+)
      )
    /x

    module_function

    def parse(expression)
      raise Dice::ParseError, "empty dice expression" if expression.nil? || expression.strip.empty?

      s = expression.strip
      pos = 0
      terms = []
      first = true

      while pos < s.length
        remaining = s[pos..]
        match = TERM_RE.match(remaining)
        raise Dice::ParseError, "unparseable at position #{pos}: #{remaining.inspect}" if match.nil?

        sign_str = match[:sign]
        sign =
          if first && sign_str.nil?
            1
          elsif sign_str.nil?
            raise Dice::ParseError, "missing operator at position #{pos}: #{remaining.inspect}"
          else
            sign_str == "+" ? 1 : -1
          end

        if match[:const]
          terms << ConstantTerm.new(value: match[:const].to_i, sign: sign)
        else
          count = match[:count].to_i
          sides = match[:sides].to_i
          raise Dice::ParseError, "count must be between 1 and #{MAX_COUNT}, got #{count}" if count < 1 || count > MAX_COUNT
          raise Dice::ParseError, "sides must be between 1 and #{MAX_SIDES}, got #{sides}" if sides < 1 || sides > MAX_SIDES

          keep = nil
          if match[:keep]
            keep_n = match[:keep_n].to_i
            raise Dice::ParseError, "keep count must be >= 1, got #{keep_n}" if keep_n < 1
            keep = [match[:keep].to_sym, keep_n]
          end

          terms << DiceTerm.new(count: count, sides: sides, sign: sign, keep: keep)
        end

        pos += match.end(0)
        first = false
        pos += 1 while pos < s.length && s[pos] == " "
      end

      raise Dice::ParseError, "no terms parsed from #{expression.inspect}" if terms.empty?

      terms
    end
  end
end
```

- [ ] **Step 3.4: Run the spec and confirm it passes**

```
bundle exec rspec spec/services/dice/parser_spec.rb
```

Expected: all examples pass (~21 examples). Fix any iteration issues until green.

- [ ] **Step 3.5: Commit**

```
git add app/services/dice/parser.rb spec/services/dice/parser_spec.rb
git commit -m "Add Dice::Parser ported from v1 with edge-case coverage (Phase 7.3)"
```

---

## Task 4: Implement `Dice::Random` with test override

`Dice::Random.roll(sides)` produces a fair die roll. Tests override the roll output via `Dice::Random.with_fixed([...])`. The override uses thread-local storage so parallel test workers don't bleed.

**Files:**
- Create: `app/services/dice/random.rb`
- Create: `spec/services/dice/random_spec.rb`

- [ ] **Step 4.1: Write the spec**

Create `spec/services/dice/random_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Dice::Random do
  describe ".roll" do
    it "returns a value between 1 and sides" do
      100.times do
        result = described_class.roll(6)
        expect(result).to be_between(1, 6)
      end
    end

    it "covers the full range over many rolls" do
      seen = Set.new
      1000.times { seen << described_class.roll(6) }
      expect(seen).to eq(Set.new([ 1, 2, 3, 4, 5, 6 ]))
    end
  end

  describe ".with_fixed" do
    it "returns the queued values in order" do
      described_class.with_fixed([ 3, 5, 1 ]) do
        expect(described_class.roll(6)).to eq(3)
        expect(described_class.roll(6)).to eq(5)
        expect(described_class.roll(6)).to eq(1)
      end
    end

    it "resets to real randomness after the block" do
      described_class.with_fixed([ 4 ]) { described_class.roll(6) }
      # Should not raise even though the queue is exhausted.
      expect(described_class.roll(6)).to be_between(1, 6)
    end

    it "raises if the queue underflows inside the block" do
      expect {
        described_class.with_fixed([ 1 ]) do
          described_class.roll(6)
          described_class.roll(6)
        end
      }.to raise_error(/fixed.*exhausted/i)
    end
  end
end
```

- [ ] **Step 4.2: Run the spec and confirm it fails**

```
bundle exec rspec spec/services/dice/random_spec.rb
```

Expected: failures referencing `uninitialized constant Dice::Random`.

- [ ] **Step 4.3: Implement `Dice::Random`**

Create `app/services/dice/random.rb`:

```ruby
require "securerandom"

module Dice
  module Random
    @fixed_queue = nil

    class << self
      attr_accessor :fixed_queue
    end

    module_function

    def roll(sides)
      queue = Dice::Random.fixed_queue
      if queue
        raise "Dice::Random fixed queue exhausted" if queue.empty?
        return queue.shift
      end
      SecureRandom.random_number(sides) + 1
    end

    def with_fixed(values)
      previous = Dice::Random.fixed_queue
      Dice::Random.fixed_queue = values.dup
      yield
    ensure
      Dice::Random.fixed_queue = previous
    end
  end
end
```

Note: module-level instance variable state (not `Thread.current`) so the stub is visible to Puma's worker thread when the system spec posts a form. The test suite runs serially within each process (`use_transactional_fixtures = true`, no `parallel_tests`), so cross-test bleeding isn't a concern.

- [ ] **Step 4.4: Run the spec and confirm it passes**

```
bundle exec rspec spec/services/dice/random_spec.rb
```

Expected: all examples pass.

- [ ] **Step 4.5: Commit**

```
git add app/services/dice/random.rb spec/services/dice/random_spec.rb
git commit -m "Add Dice::Random with test-only with_fixed override (Phase 7.4)"
```

---

## Task 5: Implement `Dice::Roll`

The entry point. Parses, rolls each die via `Dice::Random.roll`, applies keep-highest / keep-lowest, sums to a total, and returns a result value object with a per-term `breakdown` and per-term `rolls` array.

**Files:**
- Create: `app/services/dice/roll.rb`
- Create: `spec/services/dice/roll_spec.rb`

- [ ] **Step 5.1: Write the spec**

Create `spec/services/dice/roll_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Dice::Roll do
  describe ".call" do
    it "rolls a single die deterministically" do
      result = Dice::Random.with_fixed([ 4 ]) { described_class.call("1d6") }

      expect(result.expression).to eq("1d6")
      expect(result.total).to eq(4)
      expect(result.breakdown).to eq([ "1d6 = [4] = 4" ])
      expect(result.rolls).to eq([ [ 4 ] ])
    end

    it "rolls multiple dice and sums them" do
      result = Dice::Random.with_fixed([ 2, 5 ]) { described_class.call("2d6") }

      expect(result.total).to eq(7)
      expect(result.breakdown).to eq([ "2d6 = [2, 5] = 7" ])
      expect(result.rolls).to eq([ [ 2, 5 ] ])
    end

    it "adds a constant" do
      result = Dice::Random.with_fixed([ 4 ]) { described_class.call("1d6+3") }

      expect(result.total).to eq(7)
      expect(result.breakdown).to eq([ "1d6 = [4] = 4", "+3" ])
      expect(result.rolls).to eq([ [ 4 ], [] ])
    end

    it "subtracts a constant" do
      result = Dice::Random.with_fixed([ 18 ]) { described_class.call("1d20-1") }

      expect(result.total).to eq(17)
      expect(result.breakdown).to eq([ "1d20 = [18] = 18", "-1" ])
    end

    it "applies keep-highest" do
      result = Dice::Random.with_fixed([ 3, 5, 6, 2 ]) { described_class.call("4d6kh3") }

      expect(result.total).to eq(14) # 3 + 5 + 6 keep, 2 dropped
      expect(result.rolls).to eq([ [ 3, 5, 6, 2 ] ])
      expect(result.breakdown.first).to include("[3, 5, 6, 2]")
      expect(result.breakdown.first).to include("= 14")
    end

    it "applies keep-lowest" do
      result = Dice::Random.with_fixed([ 19, 2 ]) { described_class.call("2d20kl1") }

      expect(result.total).to eq(2)
    end

    it "keeps all dice when keep N >= count" do
      result = Dice::Random.with_fixed([ 1, 2, 3 ]) { described_class.call("3d6kh5") }

      expect(result.total).to eq(6)
    end

    it "rolls a constant-only expression" do
      result = described_class.call("+5")
      expect(result.total).to eq(5)
      expect(result.breakdown).to eq([ "+5" ])
      expect(result.rolls).to eq([ [] ])
    end

    it "handles a leading negative constant" do
      result = described_class.call("-3")
      expect(result.total).to eq(-3)
      expect(result.breakdown).to eq([ "-3" ])
    end

    it "raises Dice::ParseError on malformed input" do
      expect { described_class.call("not dice") }.to raise_error(Dice::ParseError)
    end
  end
end
```

- [ ] **Step 5.2: Run the spec and confirm it fails**

```
bundle exec rspec spec/services/dice/roll_spec.rb
```

Expected: failures referencing `uninitialized constant Dice::Roll`.

- [ ] **Step 5.3: Implement `Dice::Roll`**

Create `app/services/dice/roll.rb`:

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
      evaluated = terms.map { |term| evaluate(term) }

      total = evaluated.sum { |t| t[:value] }
      breakdown = evaluated.map { |t| t[:render] }
      rolls = evaluated.map { |t| t[:rolls] }

      Result.new(expression: @expression, total: total, breakdown: breakdown, rolls: rolls)
    end

    private

    def evaluate(term)
      case term
      when Dice::Parser::ConstantTerm
        value = term.sign * term.value
        { value: value, render: format_constant(term), rolls: [] }
      when Dice::Parser::DiceTerm
        rolls = Array.new(term.count) { Dice::Random.roll(term.sides) }
        kept, _dropped = apply_keep(rolls, term.keep)
        value = term.sign * kept.sum
        { value: value, render: format_dice(term, rolls, kept), rolls: rolls }
      end
    end

    def apply_keep(rolls, keep)
      return [ rolls.dup, [] ] if keep.nil?

      direction, n = keep
      return [ rolls.dup, [] ] if n >= rolls.length

      indexed = rolls.each_with_index.sort_by { |value, _| value }
      kept_indices =
        if direction == :h
          indexed.last(n).map(&:last).to_set
        else
          indexed.first(n).map(&:last).to_set
        end

      kept = rolls.each_with_index.select { |_, i| kept_indices.include?(i) }.map(&:first)
      dropped = rolls.each_with_index.reject { |_, i| kept_indices.include?(i) }.map(&:first)
      [ kept, dropped ]
    end

    def format_constant(term)
      sign = term.sign == 1 ? "+" : "-"
      "#{sign}#{term.value}"
    end

    def format_dice(term, rolls, kept)
      sign_prefix = term.sign == -1 ? "-" : ""
      keep_suffix = term.keep ? "k#{term.keep[0]}#{term.keep[1]}" : ""
      "#{sign_prefix}#{term.count}d#{term.sides}#{keep_suffix} = #{rolls.inspect} = #{kept.sum}"
    end
  end
end
```

- [ ] **Step 5.4: Run the spec and confirm it passes**

```
bundle exec rspec spec/services/dice/roll_spec.rb
```

Expected: all examples pass.

- [ ] **Step 5.5: Commit**

```
git add app/services/dice/roll.rb spec/services/dice/roll_spec.rb
git commit -m "Add Dice::Roll service object (Phase 7.5)"
```

---

## Task 6: Smoke-test dice services end-to-end

A quick `bin/rails runner` sanity check that the public API works as designed.

- [ ] **Step 6.1: Run the dice spec suite**

```
bundle exec rspec spec/services/dice
```

Expected: all examples pass (~36 examples across parser, random, roll).

- [ ] **Step 6.2: Smoke-test in a runner**

```
bin/rails runner '
  r = Dice::Roll.call("4d6kh3")
  puts r.inspect
  puts "total=#{r.total} breakdown=#{r.breakdown.inspect} rolls=#{r.rolls.inspect}"
'
```

Expected: a result with total between 3 and 18, breakdown containing one entry, rolls containing one 4-element array.

(No new commit — this task is verification only.)

---

## Task 7: Define the `Mythic` module

**Files:**
- Create: `app/services/mythic.rb`

- [ ] **Step 7.1: Create the module file**

Write `app/services/mythic.rb`:

```ruby
module Mythic
end
```

- [ ] **Step 7.2: Commit**

```
git add app/services/mythic.rb
git commit -m "Add Mythic module (Phase 7.7)"
```

---

## Task 8: Implement `Mythic::FateChart`

The 81-cell table from Mythic GME 2e p.19. Transcribe verbatim from v1's `tools/mythic/src/mythic/fate_chart.py` (visible via `git show v1-final-poc:tools/mythic/src/mythic/fate_chart.py`).

**Files:**
- Create: `app/services/mythic/fate_chart.rb`
- Create: `spec/services/mythic/fate_chart_spec.rb`

- [ ] **Step 8.1: Write the spec**

Create `spec/services/mythic/fate_chart_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Mythic::FateChart do
  describe "LIKELIHOODS" do
    it "lists the 9 Mythic 2e likelihood values in worst-to-best order" do
      expect(described_class::LIKELIHOODS).to eq(%w[
        impossible nearly_impossible very_unlikely unlikely
        50_50
        likely very_likely nearly_certain certain
      ])
    end
  end

  describe "CHART" do
    it "covers all 81 cells" do
      expected_keys = described_class::LIKELIHOODS.product((1..9).to_a)
      expect(described_class::CHART.keys.sort).to eq(expected_keys.sort)
    end

    it "each cell is a 4-tuple with 0 <= a <= b <= c <= d == 100" do
      described_class::CHART.each do |(likelihood, cf), bands|
        a, b, c, d = bands
        expect(bands.length).to eq(4), "cell #{[likelihood, cf].inspect} has #{bands.length} values"
        expect(a).to be >= 0
        expect(a).to be <= b
        expect(b).to be <= c
        expect(c).to be <= d
        expect(d).to eq(100), "cell #{[likelihood, cf].inspect} has exc_no_max=#{d}, expected 100"
      end
    end

    it "matches the worked example on p.24 (50_50, CF 5 -> 10 50 91)" do
      expect(described_class::CHART[[ "50_50", 5 ]]).to eq([ 10, 50, 90, 100 ])
    end
  end

  describe ".bands_for" do
    it "returns the cell for valid (likelihood, chaos_factor)" do
      expect(described_class.bands_for(likelihood: "likely", chaos_factor: 5))
        .to eq([ 13, 65, 93, 100 ])
    end

    it "raises ArgumentError for an unknown likelihood" do
      expect {
        described_class.bands_for(likelihood: "extremely", chaos_factor: 5)
      }.to raise_error(ArgumentError, /no chart cell/)
    end

    it "raises ArgumentError for a chaos factor outside 1..9" do
      expect {
        described_class.bands_for(likelihood: "likely", chaos_factor: 0)
      }.to raise_error(ArgumentError, /no chart cell/)
    end
  end

  describe ".outcome_for" do
    let(:bands) { [ 10, 50, 90, 100 ] } # 50_50 / CF 5

    it "returns :exceptional_yes for roll <= exc_yes_max" do
      expect(described_class.outcome_for(roll: 1, bands: bands)).to eq(:exceptional_yes)
      expect(described_class.outcome_for(roll: 10, bands: bands)).to eq(:exceptional_yes)
    end

    it "returns :yes for exc_yes_max < roll <= yes_max" do
      expect(described_class.outcome_for(roll: 11, bands: bands)).to eq(:yes)
      expect(described_class.outcome_for(roll: 50, bands: bands)).to eq(:yes)
    end

    it "returns :no for yes_max < roll <= no_max" do
      expect(described_class.outcome_for(roll: 51, bands: bands)).to eq(:no)
      expect(described_class.outcome_for(roll: 90, bands: bands)).to eq(:no)
    end

    it "returns :exceptional_no for no_max < roll <= exc_no_max" do
      expect(described_class.outcome_for(roll: 91, bands: bands)).to eq(:exceptional_no)
      expect(described_class.outcome_for(roll: 100, bands: bands)).to eq(:exceptional_no)
    end
  end
end
```

- [ ] **Step 8.2: Run the spec and confirm it fails**

```
bundle exec rspec spec/services/mythic/fate_chart_spec.rb
```

Expected: failures referencing `uninitialized constant Mythic::FateChart`.

- [ ] **Step 8.3: Implement `Mythic::FateChart` (transcribe the 81-cell table)**

Create `app/services/mythic/fate_chart.rb`. The implementation has three parts: the `LIKELIHOODS` array, the `CHART` hash (transcribed verbatim from v1), and the two helper methods.

To transcribe `CHART`, run this command to inspect the v1 source side-by-side:

```
git show v1-final-poc:tools/mythic/src/mythic/fate_chart.py | sed -n '/^FATE_CHART/,/^}/p'
```

Now write the Ruby file:

```ruby
module Mythic
  module FateChart
    LIKELIHOODS = %w[
      impossible nearly_impossible very_unlikely unlikely
      50_50
      likely very_likely nearly_certain certain
    ].freeze

    # CHART[[likelihood, chaos]] = [exc_yes_max, yes_max, no_max, exc_no_max].
    # Transcribed verbatim from v1's tools/mythic/src/mythic/fate_chart.py
    # (visible at the v1-final-poc tag), which itself transcribes the Fate Chart
    # on page 19 of references/MythicGME2eV2.pdf.
    CHART = {
      [ "certain", 1 ] => [ 10, 50, 90, 100 ],
      [ "certain", 2 ] => [ 13, 65, 93, 100 ],
      [ "certain", 3 ] => [ 15, 75, 95, 100 ],
      [ "certain", 4 ] => [ 17, 85, 97, 100 ],
      [ "certain", 5 ] => [ 18, 90, 98, 100 ],
      [ "certain", 6 ] => [ 19, 95, 99, 100 ],
      [ "certain", 7 ] => [ 20, 99, 100, 100 ],
      [ "certain", 8 ] => [ 20, 99, 100, 100 ],
      [ "certain", 9 ] => [ 20, 99, 100, 100 ],

      [ "nearly_certain", 1 ] => [ 7, 35, 87, 100 ],
      [ "nearly_certain", 2 ] => [ 10, 50, 90, 100 ],
      [ "nearly_certain", 3 ] => [ 13, 65, 93, 100 ],
      [ "nearly_certain", 4 ] => [ 15, 75, 95, 100 ],
      [ "nearly_certain", 5 ] => [ 17, 85, 97, 100 ],
      [ "nearly_certain", 6 ] => [ 18, 90, 98, 100 ],
      [ "nearly_certain", 7 ] => [ 19, 95, 99, 100 ],
      [ "nearly_certain", 8 ] => [ 20, 99, 100, 100 ],
      [ "nearly_certain", 9 ] => [ 20, 99, 100, 100 ],

      [ "very_likely", 1 ] => [ 5, 25, 85, 100 ],
      [ "very_likely", 2 ] => [ 7, 35, 87, 100 ],
      [ "very_likely", 3 ] => [ 10, 50, 90, 100 ],
      [ "very_likely", 4 ] => [ 13, 65, 93, 100 ],
      [ "very_likely", 5 ] => [ 15, 75, 95, 100 ],
      [ "very_likely", 6 ] => [ 17, 85, 97, 100 ],
      [ "very_likely", 7 ] => [ 18, 90, 98, 100 ],
      [ "very_likely", 8 ] => [ 19, 95, 99, 100 ],
      [ "very_likely", 9 ] => [ 20, 99, 100, 100 ],

      [ "likely", 1 ] => [ 3, 15, 83, 100 ],
      [ "likely", 2 ] => [ 5, 25, 85, 100 ],
      [ "likely", 3 ] => [ 7, 35, 87, 100 ],
      [ "likely", 4 ] => [ 10, 50, 90, 100 ],
      [ "likely", 5 ] => [ 13, 65, 93, 100 ],
      [ "likely", 6 ] => [ 15, 75, 95, 100 ],
      [ "likely", 7 ] => [ 17, 85, 97, 100 ],
      [ "likely", 8 ] => [ 18, 90, 98, 100 ],
      [ "likely", 9 ] => [ 19, 95, 99, 100 ],

      [ "50_50", 1 ] => [ 2, 10, 82, 100 ],
      [ "50_50", 2 ] => [ 3, 15, 83, 100 ],
      [ "50_50", 3 ] => [ 5, 25, 85, 100 ],
      [ "50_50", 4 ] => [ 7, 35, 87, 100 ],
      [ "50_50", 5 ] => [ 10, 50, 90, 100 ],
      [ "50_50", 6 ] => [ 13, 65, 93, 100 ],
      [ "50_50", 7 ] => [ 15, 75, 95, 100 ],
      [ "50_50", 8 ] => [ 17, 85, 97, 100 ],
      [ "50_50", 9 ] => [ 18, 90, 98, 100 ],

      [ "unlikely", 1 ] => [ 1, 5, 81, 100 ],
      [ "unlikely", 2 ] => [ 2, 10, 82, 100 ],
      [ "unlikely", 3 ] => [ 3, 15, 83, 100 ],
      [ "unlikely", 4 ] => [ 5, 25, 85, 100 ],
      [ "unlikely", 5 ] => [ 7, 35, 87, 100 ],
      [ "unlikely", 6 ] => [ 10, 50, 90, 100 ],
      [ "unlikely", 7 ] => [ 13, 65, 93, 100 ],
      [ "unlikely", 8 ] => [ 15, 75, 95, 100 ],
      [ "unlikely", 9 ] => [ 17, 85, 97, 100 ],

      [ "very_unlikely", 1 ] => [ 0, 1, 80, 100 ],
      [ "very_unlikely", 2 ] => [ 1, 5, 81, 100 ],
      [ "very_unlikely", 3 ] => [ 2, 10, 82, 100 ],
      [ "very_unlikely", 4 ] => [ 3, 15, 83, 100 ],
      [ "very_unlikely", 5 ] => [ 5, 25, 85, 100 ],
      [ "very_unlikely", 6 ] => [ 7, 35, 87, 100 ],
      [ "very_unlikely", 7 ] => [ 10, 50, 90, 100 ],
      [ "very_unlikely", 8 ] => [ 13, 65, 93, 100 ],
      [ "very_unlikely", 9 ] => [ 15, 75, 95, 100 ],

      [ "nearly_impossible", 1 ] => [ 0, 1, 80, 100 ],
      [ "nearly_impossible", 2 ] => [ 0, 1, 80, 100 ],
      [ "nearly_impossible", 3 ] => [ 1, 5, 81, 100 ],
      [ "nearly_impossible", 4 ] => [ 2, 10, 82, 100 ],
      [ "nearly_impossible", 5 ] => [ 3, 15, 83, 100 ],
      [ "nearly_impossible", 6 ] => [ 5, 25, 85, 100 ],
      [ "nearly_impossible", 7 ] => [ 7, 35, 87, 100 ],
      [ "nearly_impossible", 8 ] => [ 10, 50, 90, 100 ],
      [ "nearly_impossible", 9 ] => [ 13, 65, 93, 100 ],

      [ "impossible", 1 ] => [ 0, 1, 80, 100 ],
      [ "impossible", 2 ] => [ 0, 1, 80, 100 ],
      [ "impossible", 3 ] => [ 0, 1, 80, 100 ],
      [ "impossible", 4 ] => [ 1, 5, 81, 100 ],
      [ "impossible", 5 ] => [ 2, 10, 82, 100 ],
      [ "impossible", 6 ] => [ 3, 15, 83, 100 ],
      [ "impossible", 7 ] => [ 5, 25, 85, 100 ],
      [ "impossible", 8 ] => [ 7, 35, 87, 100 ],
      [ "impossible", 9 ] => [ 10, 50, 90, 100 ]
    }.freeze

    module_function

    def bands_for(likelihood:, chaos_factor:)
      CHART.fetch([ likelihood, chaos_factor ]) do
        raise ArgumentError,
              "no chart cell for likelihood=#{likelihood.inspect} chaos=#{chaos_factor.inspect}"
      end
    end

    def outcome_for(roll:, bands:)
      exc_yes_max, yes_max, no_max, _exc_no_max = bands
      return :exceptional_yes if roll <= exc_yes_max
      return :yes             if roll <= yes_max
      return :no              if roll <= no_max
      :exceptional_no
    end
  end
end
```

Cross-check: the resulting Ruby file should have exactly 81 `=>` entries inside `CHART`. Run `grep -c '=>' app/services/mythic/fate_chart.rb` and verify the count is 81.

- [ ] **Step 8.4: Run the spec and confirm it passes**

```
bundle exec rspec spec/services/mythic/fate_chart_spec.rb
```

Expected: all examples pass. If the "81 cells" check fails, recount and fix.

- [ ] **Step 8.5: Commit**

```
git add app/services/mythic/fate_chart.rb spec/services/mythic/fate_chart_spec.rb
git commit -m "Add Mythic::FateChart with 81-cell Mythic 2e table (Phase 7.8)"
```

---

## Task 9: Implement `Mythic::Random` with test override

Same shape as `Dice::Random` — a thin `SecureRandom` wrapper with a `with_fixed_d100` test override.

**Files:**
- Create: `app/services/mythic/random.rb`
- Create: `spec/services/mythic/random_spec.rb`

- [ ] **Step 9.1: Write the spec**

Create `spec/services/mythic/random_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Mythic::Random do
  describe ".d100" do
    it "returns a value between 1 and 100" do
      100.times do
        result = described_class.d100
        expect(result).to be_between(1, 100)
      end
    end

    it "covers a wide range across many rolls" do
      seen = Set.new
      1000.times { seen << described_class.d100 }
      expect(seen.size).to be > 50
    end
  end

  describe ".with_fixed_d100" do
    it "returns the queued values in order" do
      described_class.with_fixed_d100([ 11, 50, 99 ]) do
        expect(described_class.d100).to eq(11)
        expect(described_class.d100).to eq(50)
        expect(described_class.d100).to eq(99)
      end
    end

    it "resets to real randomness after the block" do
      described_class.with_fixed_d100([ 42 ]) { described_class.d100 }
      expect(described_class.d100).to be_between(1, 100)
    end

    it "raises if the queue underflows inside the block" do
      expect {
        described_class.with_fixed_d100([ 1 ]) do
          described_class.d100
          described_class.d100
        end
      }.to raise_error(/fixed.*exhausted/i)
    end
  end
end
```

- [ ] **Step 9.2: Run the spec and confirm it fails**

```
bundle exec rspec spec/services/mythic/random_spec.rb
```

Expected: failures referencing `uninitialized constant Mythic::Random`.

- [ ] **Step 9.3: Implement `Mythic::Random`**

Create `app/services/mythic/random.rb`:

```ruby
require "securerandom"

module Mythic
  module Random
    @fixed_queue = nil

    class << self
      attr_accessor :fixed_queue
    end

    module_function

    def d100
      queue = Mythic::Random.fixed_queue
      if queue
        raise "Mythic::Random fixed queue exhausted" if queue.empty?
        return queue.shift
      end
      SecureRandom.random_number(100) + 1
    end

    def with_fixed_d100(values)
      previous = Mythic::Random.fixed_queue
      Mythic::Random.fixed_queue = values.dup
      yield
    ensure
      Mythic::Random.fixed_queue = previous
    end
  end
end
```

Note: same module-level pattern as `Dice::Random` — works across Puma worker threads in system specs.

- [ ] **Step 9.4: Run the spec and confirm it passes**

```
bundle exec rspec spec/services/mythic/random_spec.rb
```

Expected: all examples pass.

- [ ] **Step 9.5: Commit**

```
git add app/services/mythic/random.rb spec/services/mythic/random_spec.rb
git commit -m "Add Mythic::Random with with_fixed_d100 override (Phase 7.9)"
```

---

## Task 10: Implement `Mythic::Oracle`

The entry point. Combines `Mythic::FateChart` + `Mythic::Random` + the Mythic 2e p.35 random-event-trigger rule.

**Files:**
- Create: `app/services/mythic/oracle.rb`
- Create: `spec/services/mythic/oracle_spec.rb`

- [ ] **Step 10.1: Write the spec**

Create `spec/services/mythic/oracle_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Mythic::Oracle do
  describe ".call" do
    it "returns a structured result with all fields populated" do
      result = Mythic::Random.with_fixed_d100([ 50 ]) do
        described_class.call(question: "Does it rain?", likelihood: "50_50", chaos_factor: 5)
      end

      expect(result.question).to eq("Does it rain?")
      expect(result.likelihood).to eq("50_50")
      expect(result.chaos_factor).to eq(5)
      expect(result.roll).to eq(50)
      expect(result.outcome).to eq(:yes) # roll 50 sits at the high end of the yes band (10 50 90 100)
      expect(result.random_event_triggered).to eq(false)
    end

    it "selects each outcome band correctly for 50_50 / CF 5 (bands 10 50 90 100)" do
      cases = {
        1   => :exceptional_yes,
        10  => :exceptional_yes,
        11  => :yes,
        50  => :yes,
        51  => :no,
        90  => :no,
        91  => :exceptional_no,
        100 => :exceptional_no
      }

      cases.each do |roll, expected_outcome|
        result = Mythic::Random.with_fixed_d100([ roll ]) do
          described_class.call(question: "q", likelihood: "50_50", chaos_factor: 5)
        end
        expect(result.outcome).to eq(expected_outcome),
          "expected roll #{roll} to produce #{expected_outcome}, got #{result.outcome}"
      end
    end

    describe "random event trigger rule (Mythic 2e p.35)" do
      # Trigger if and only if the roll is a doubled-digit value (11, 22, ..., 99)
      # AND the leading digit is <= chaos_factor.

      [ 11, 22, 33, 44, 55, 66, 77, 88, 99 ].each do |roll|
        leading_digit = roll / 10

        it "triggers when roll=#{roll} and chaos_factor=#{leading_digit}" do
          result = Mythic::Random.with_fixed_d100([ roll ]) do
            described_class.call(question: "q", likelihood: "50_50", chaos_factor: leading_digit)
          end
          expect(result.random_event_triggered).to eq(true)
        end

        if leading_digit > 1
          it "does NOT trigger when roll=#{roll} and chaos_factor=#{leading_digit - 1}" do
            result = Mythic::Random.with_fixed_d100([ roll ]) do
              described_class.call(question: "q", likelihood: "50_50", chaos_factor: leading_digit - 1)
            end
            expect(result.random_event_triggered).to eq(false)
          end
        end
      end

      [ 1, 5, 10, 12, 21, 47, 89, 100 ].each do |roll|
        it "never triggers for non-doubled roll=#{roll} regardless of chaos" do
          (1..9).each do |cf|
            result = Mythic::Random.with_fixed_d100([ roll ]) do
              described_class.call(question: "q", likelihood: "50_50", chaos_factor: cf)
            end
            expect(result.random_event_triggered).to eq(false),
              "expected roll=#{roll} chaos=#{cf} not to trigger"
          end
        end
      end
    end

    it "raises ArgumentError for an invalid likelihood" do
      expect {
        described_class.call(question: "q", likelihood: "definitely", chaos_factor: 5)
      }.to raise_error(ArgumentError)
    end

    it "raises ArgumentError for an out-of-range chaos factor" do
      expect {
        described_class.call(question: "q", likelihood: "50_50", chaos_factor: 0)
      }.to raise_error(ArgumentError)
    end
  end
end
```

- [ ] **Step 10.2: Run the spec and confirm it fails**

```
bundle exec rspec spec/services/mythic/oracle_spec.rb
```

Expected: failures referencing `uninitialized constant Mythic::Oracle`.

- [ ] **Step 10.3: Implement `Mythic::Oracle`**

Create `app/services/mythic/oracle.rb`:

```ruby
module Mythic
  class Oracle
    Result = Data.define(
      :question, :likelihood, :chaos_factor,
      :roll, :outcome, :random_event_triggered
    )

    def self.call(question:, likelihood:, chaos_factor:)
      bands = Mythic::FateChart.bands_for(likelihood: likelihood, chaos_factor: chaos_factor)
      roll = Mythic::Random.d100
      outcome = Mythic::FateChart.outcome_for(roll: roll, bands: bands)
      triggered = random_event?(roll: roll, chaos_factor: chaos_factor)

      Result.new(
        question: question,
        likelihood: likelihood,
        chaos_factor: chaos_factor,
        roll: roll,
        outcome: outcome,
        random_event_triggered: triggered
      )
    end

    def self.random_event?(roll:, chaos_factor:)
      return false unless roll.between?(11, 99)

      tens, units = roll.divmod(10)
      tens == units && tens <= chaos_factor
    end
  end
end
```

- [ ] **Step 10.4: Run the spec and confirm it passes**

```
bundle exec rspec spec/services/mythic/oracle_spec.rb
```

Expected: all examples pass (~40 examples).

- [ ] **Step 10.5: Run the full Mythic + Dice spec suite**

```
bundle exec rspec spec/services
```

Expected: green across all dice and mythic specs.

- [ ] **Step 10.6: Commit**

```
git add app/services/mythic/oracle.rb spec/services/mythic/oracle_spec.rb
git commit -m "Add Mythic::Oracle service with random-event trigger rule (Phase 7.10)"
```

---

## Task 11: Wire routes

**Files:**
- Modify: `config/routes/play.rb`
- Modify: `config/routes/admin.rb`

- [ ] **Step 11.1: Update `config/routes/play.rb`**

Replace the existing `resources :scenes` block inside the `scope module: "play"` so it has nested `dice_rolls` and `oracle_queries`:

```ruby
constraints subdomain: "" do
  devise_for :users, skip: [ :registrations ], controllers: { sessions: "users/sessions" }

  root "play/home#show"

  scope module: "play" do
    resources :campaigns, only: [ :index ] do
      member { get :play }

      resources :scenes, only: [] do
        member { get :play }

        resources :dice_rolls,     only: [ :create ]
        resources :oracle_queries, only: [ :create ]
      end
    end
  end
end
```

- [ ] **Step 11.2: Update `config/routes/admin.rb`**

Add a singleton `chaos_factor` resource inside the `resources :campaigns` block:

```ruby
constraints subdomain: "admin" do
  scope module: "admin", as: :admin do
    root to: redirect("/campaigns")

    resources :campaigns do
      resource :chaos_factor, only: [ :update ], controller: "chaos_factors"

      resources :scenes do
        member do
          post :move_up
          post :move_down
        end
      end
    end

    namespace :diagnostics do
      resource :llm, only: [ :show, :create ], controller: "llm"
    end
  end
end
```

- [ ] **Step 11.3: Verify routes resolve**

```
bin/rails routes | grep -E "(dice_rolls|oracle_queries|chaos_factor)"
```

Expected:
```
play_campaign_scene_dice_rolls POST /campaigns/:campaign_id/scenes/:scene_id/dice_rolls(.:format) play/dice_rolls#create
play_campaign_scene_oracle_queries POST /campaigns/:campaign_id/scenes/:scene_id/oracle_queries(.:format) play/oracle_queries#create
admin_campaign_chaos_factor PATCH /campaigns/:campaign_id/chaos_factor(.:format) admin/chaos_factors#update
admin_campaign_chaos_factor PUT /campaigns/:campaign_id/chaos_factor(.:format) admin/chaos_factors#update
```

- [ ] **Step 11.4: Commit**

```
git add config/routes/play.rb config/routes/admin.rb
git commit -m "Add Phase 7 routes (dice_rolls, oracle_queries, chaos_factor) (Phase 7.11)"
```

---

## Task 12: Build `Admin::Campaigns::ChaosFactorComponent`

**Files:**
- Create: `app/components/admin/campaigns/chaos_factor_component.rb`
- Create: `app/components/admin/campaigns/chaos_factor_component.html.erb`
- Create: `spec/components/admin/campaigns/chaos_factor_component_spec.rb`

- [ ] **Step 12.1: Write the component spec**

Create `spec/components/admin/campaigns/chaos_factor_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Admin::Campaigns::ChaosFactorComponent, type: :component do
  let(:user) { create(:user) }

  it "renders the current chaos factor" do
    campaign = create(:campaign, user: user, chaos_factor: 5)
    render_inline(described_class.new(campaign: campaign))

    expect(page).to have_text(/chaos factor/i)
    expect(page).to have_text("5")
  end

  it "renders − and + buttons" do
    campaign = create(:campaign, user: user, chaos_factor: 5)
    render_inline(described_class.new(campaign: campaign))

    expect(page).to have_button("−")
    expect(page).to have_button("+")
  end

  it "disables the − button at the floor" do
    campaign = create(:campaign, user: user, chaos_factor: 1)
    render_inline(described_class.new(campaign: campaign))

    expect(page).to have_button("−", disabled: true)
    expect(page).to have_button("+", disabled: false)
  end

  it "disables the + button at the ceiling" do
    campaign = create(:campaign, user: user, chaos_factor: 9)
    render_inline(described_class.new(campaign: campaign))

    expect(page).to have_button("−", disabled: false)
    expect(page).to have_button("+", disabled: true)
  end
end
```

- [ ] **Step 12.2: Run the spec and confirm it fails**

```
bundle exec rspec spec/components/admin/campaigns/chaos_factor_component_spec.rb
```

Expected: failures referencing `uninitialized constant Admin::Campaigns::ChaosFactorComponent`.

- [ ] **Step 12.3: Implement the component class**

Create `app/components/admin/campaigns/chaos_factor_component.rb`:

```ruby
module Admin
  module Campaigns
    class ChaosFactorComponent < ViewComponent::Base
      def initialize(campaign:)
        @campaign = campaign
      end

      attr_reader :campaign

      def at_floor?
        campaign.chaos_factor <= 1
      end

      def at_ceiling?
        campaign.chaos_factor >= 9
      end
    end
  end
end
```

- [ ] **Step 12.4: Implement the component template**

Create `app/components/admin/campaigns/chaos_factor_component.html.erb`:

```erb
<div class="mt-8 rounded border border-slate-800 bg-slate-900/50 px-4 py-3">
  <div class="flex items-center justify-between gap-4">
    <div>
      <p class="text-xs uppercase tracking-widest text-slate-400">Chaos factor</p>
      <p class="mt-1 text-2xl font-semibold text-slate-100"><%= campaign.chaos_factor %></p>
    </div>
    <div class="flex items-center gap-2">
      <%= button_to "−",
                    helpers.admin_campaign_chaos_factor_path(campaign),
                    method: :patch,
                    params: { direction: "down" },
                    disabled: at_floor?,
                    data: { direction: "down" },
                    class: "rounded bg-slate-800 px-3 py-1 text-lg text-slate-200 hover:bg-slate-700 disabled:opacity-30 disabled:cursor-not-allowed" %>
      <%= button_to "+",
                    helpers.admin_campaign_chaos_factor_path(campaign),
                    method: :patch,
                    params: { direction: "up" },
                    disabled: at_ceiling?,
                    data: { direction: "up" },
                    class: "rounded bg-slate-800 px-3 py-1 text-lg text-slate-200 hover:bg-slate-700 disabled:opacity-30 disabled:cursor-not-allowed" %>
    </div>
  </div>
</div>
```

- [ ] **Step 12.5: Run the spec and confirm it passes**

```
bundle exec rspec spec/components/admin/campaigns/chaos_factor_component_spec.rb
```

Expected: 4 examples, 0 failures.

- [ ] **Step 12.6: Commit**

```
git add app/components/admin/campaigns/chaos_factor_component.rb app/components/admin/campaigns/chaos_factor_component.html.erb spec/components/admin/campaigns/chaos_factor_component_spec.rb
git commit -m "Add Admin::Campaigns::ChaosFactorComponent (Phase 7.12)"
```

---

## Task 13: Build `Admin::ChaosFactorsController`

**Files:**
- Create: `app/controllers/admin/chaos_factors_controller.rb`
- Create: `spec/requests/admin/chaos_factors_spec.rb`

- [ ] **Step 13.1: Write the request spec**

Create `spec/requests/admin/chaos_factors_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Admin::ChaosFactors", type: :request do
  before { host! "admin.gygaxagain.com" }

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:campaign) { create(:campaign, user: user, chaos_factor: 5) }

  describe "PATCH /campaigns/:campaign_id/chaos_factor" do
    context "authenticated" do
      before { sign_in user }

      it "increments when direction=up" do
        patch "/campaigns/#{campaign.id}/chaos_factor", params: { direction: "up" }

        expect(response).to redirect_to("/campaigns/#{campaign.id}")
        expect(campaign.reload.chaos_factor).to eq(6)
      end

      it "decrements when direction=down" do
        patch "/campaigns/#{campaign.id}/chaos_factor", params: { direction: "down" }

        expect(response).to redirect_to("/campaigns/#{campaign.id}")
        expect(campaign.reload.chaos_factor).to eq(4)
      end

      it "clamps at the ceiling" do
        campaign.update!(chaos_factor: 9)
        patch "/campaigns/#{campaign.id}/chaos_factor", params: { direction: "up" }

        expect(campaign.reload.chaos_factor).to eq(9)
      end

      it "clamps at the floor" do
        campaign.update!(chaos_factor: 1)
        patch "/campaigns/#{campaign.id}/chaos_factor", params: { direction: "down" }

        expect(campaign.reload.chaos_factor).to eq(1)
      end

      it "is a no-op when direction is missing or invalid" do
        patch "/campaigns/#{campaign.id}/chaos_factor", params: { direction: "" }
        expect(campaign.reload.chaos_factor).to eq(5)

        patch "/campaigns/#{campaign.id}/chaos_factor", params: { direction: "sideways" }
        expect(campaign.reload.chaos_factor).to eq(5)
      end

      it "returns 404 for a campaign owned by another user" do
        other_campaign = create(:campaign, user: other_user, chaos_factor: 5)
        expect {
          patch "/campaigns/#{other_campaign.id}/chaos_factor", params: { direction: "up" }
        }.to raise_error(ActiveRecord::RecordNotFound)
        expect(other_campaign.reload.chaos_factor).to eq(5)
      end
    end

    context "unauthenticated" do
      it "redirects to apex sign-in" do
        patch "/campaigns/#{campaign.id}/chaos_factor", params: { direction: "up" }
        expect(response).to have_http_status(:found)
        expect(response.location).to include("gygaxagain.com/users/sign_in")
      end
    end
  end
end
```

- [ ] **Step 13.2: Run the spec and confirm it fails**

```
bundle exec rspec spec/requests/admin/chaos_factors_spec.rb
```

Expected: failures referencing `uninitialized constant Admin::ChaosFactorsController`.

- [ ] **Step 13.3: Implement the controller**

Create `app/controllers/admin/chaos_factors_controller.rb`:

```ruby
module Admin
  class ChaosFactorsController < Admin::ApplicationController
    before_action :load_campaign

    def update
      delta =
        case params[:direction]
        when "up"   then  1
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

- [ ] **Step 13.4: Run the spec and confirm it passes**

```
bundle exec rspec spec/requests/admin/chaos_factors_spec.rb
```

Expected: all examples pass.

- [ ] **Step 13.5: Commit**

```
git add app/controllers/admin/chaos_factors_controller.rb spec/requests/admin/chaos_factors_spec.rb
git commit -m "Add Admin::ChaosFactorsController (Phase 7.13)"
```

---

## Task 14: Render the chaos panel on `Admin::Campaigns::ShowComponent`

**Files:**
- Modify: `app/components/admin/campaigns/show_component.html.erb`
- Modify: `spec/components/admin/campaigns/show_component_spec.rb`

- [ ] **Step 14.1: Add a failing assertion to the show component spec**

Open `spec/components/admin/campaigns/show_component_spec.rb`. Add a new example inside the existing top-level describe block:

```ruby
describe "chaos factor panel" do
  let(:user) { create(:user) }
  let(:campaign) { create(:campaign, user: user, chaos_factor: 4) }

  it "renders the chaos factor component" do
    render_inline(described_class.new(campaign: campaign))

    expect(page).to have_text(/chaos factor/i)
    expect(page).to have_text("4")
  end
end
```

- [ ] **Step 14.2: Run the spec and confirm the new example fails**

```
bundle exec rspec spec/components/admin/campaigns/show_component_spec.rb -e "chaos factor panel"
```

Expected: failure with "expected to have text 'chaos factor'".

- [ ] **Step 14.3: Render the panel in the show component template**

Edit `app/components/admin/campaigns/show_component.html.erb`. Add a render call immediately after the campaign description paragraph and before the scenes section:

```erb
<div class="mx-auto max-w-3xl">
  <div class="mb-2">
    <%= link_to "← Back to campaigns",
                helpers.admin_campaigns_path,
                class: "text-xs uppercase tracking-widest text-slate-400 hover:text-slate-200" %>
  </div>

  <h1 class="text-3xl font-bold tracking-tight"><%= campaign.name %></h1>
  <% if campaign.description.present? %>
    <p class="mt-3 text-slate-300"><%= campaign.description %></p>
  <% end %>

  <%= render Admin::Campaigns::ChaosFactorComponent.new(campaign: campaign) %>

  <div class="mt-10">
    <%# ... existing scenes section unchanged ... %>
  </div>
</div>
```

(Apply only the `<%= render Admin::Campaigns::ChaosFactorComponent.new(...) %>` insertion; leave the rest of the file as-is.)

- [ ] **Step 14.4: Run the spec and confirm it passes**

```
bundle exec rspec spec/components/admin/campaigns/show_component_spec.rb
```

Expected: all examples pass.

- [ ] **Step 14.5: Commit**

```
git add app/components/admin/campaigns/show_component.html.erb spec/components/admin/campaigns/show_component_spec.rb
git commit -m "Render chaos factor panel on Admin::Campaigns::ShowComponent (Phase 7.14)"
```

---

## Task 15: Build `Play::Dice::FormComponent`

The dice form has a stick-on-error expression input, a Roll submit button, and four quick-roll chips (`d20`, `d100`, `2d6`, `4d6kh3`). It carries an optional `error:` parameter for inline error display.

**Files:**
- Create: `app/components/play/dice/form_component.rb`
- Create: `app/components/play/dice/form_component.html.erb`
- Create: `spec/components/play/dice/form_component_spec.rb`

- [ ] **Step 15.1: Write the spec**

Create `spec/components/play/dice/form_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Play::Dice::FormComponent, type: :component do
  include Rails.application.routes.url_helpers

  let(:user) { create(:user) }
  let(:campaign) { create(:campaign, user: user) }
  let(:scene)    { create(:scene, campaign: campaign) }

  it "renders an expression input and a Roll button" do
    render_inline(described_class.new(scene: scene))

    expect(page).to have_field("dice_roll[expression]")
    expect(page).to have_button(/roll/i)
  end

  it "posts to the dice_rolls#create route" do
    render_inline(described_class.new(scene: scene))

    expected_path = play_campaign_scene_dice_rolls_path(campaign, scene)
    expect(page.find("form")["action"]).to eq(expected_path)
  end

  it "renders the four quick-roll chips" do
    render_inline(described_class.new(scene: scene))

    %w[d20 d100 2d6 4d6kh3].each do |chip|
      expect(page).to have_button(chip)
    end
  end

  it "echoes a sticky expression on error" do
    render_inline(described_class.new(scene: scene, expression: "1d6+wat"))

    expect(page.find_field("dice_roll[expression]").value).to eq("1d6+wat")
  end

  it "renders the inline error when provided" do
    render_inline(described_class.new(scene: scene, error: "unparseable at position 3"))

    expect(page).to have_text(/unparseable/)
  end

  it "includes the dice-form Stimulus controller hook" do
    render_inline(described_class.new(scene: scene))

    expect(page).to have_css("form[data-controller~='dice-form']")
  end

  it "carries the scene's dom_id on its container element" do
    render_inline(described_class.new(scene: scene))

    expect(page).to have_css("##{ApplicationController.helpers.dom_id(scene, :dice_form)}")
  end

  describe "asymmetry" do
    let(:faction) { create(:faction, campaign: campaign) }
    let(:npc)     { create(:npc, campaign: campaign) }

    before do
      create(:faction_secret, faction: faction, label: "hidden temple", content: "in the swamp")
      create(:npc_secret,     npc: npc,         label: "true identity", content: "is a doppelganger")
    end

    it "does not leak secrets of related records" do
      rendered = render_inline(described_class.new(scene: scene)).to_s
      expect(rendered).not_to leak_secrets_of(faction, npc)
    end
  end
end
```

- [ ] **Step 15.2: Run the spec and confirm it fails**

```
bundle exec rspec spec/components/play/dice/form_component_spec.rb
```

Expected: failures referencing `uninitialized constant Play::Dice::FormComponent`.

- [ ] **Step 15.3: Implement the component class**

Create `app/components/play/dice/form_component.rb`:

```ruby
module Play
  module Dice
    class FormComponent < ViewComponent::Base
      QUICK_CHIPS = %w[d20 d100 2d6 4d6kh3].freeze

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

      def quick_chips
        QUICK_CHIPS
      end
    end
  end
end
```

- [ ] **Step 15.4: Implement the component template**

Create `app/components/play/dice/form_component.html.erb`:

```erb
<div id="<%= container_dom_id %>"
     class="rounded-lg border border-slate-800 bg-slate-900/40 p-4">
  <%= form_with url: helpers.play_campaign_scene_dice_rolls_path(campaign, scene),
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
                       class: "flex-1 rounded bg-slate-800 px-3 py-2 text-slate-100 placeholder:text-slate-500 focus:outline-none focus:ring-1 focus:ring-amber-400" %>
      <%= f.submit "Roll",
                   class: "rounded bg-amber-500 px-4 py-2 font-semibold text-slate-900 hover:bg-amber-400" %>
    </div>

    <% if error.present? %>
      <p class="mt-2 text-xs text-rose-400"><%= error %></p>
    <% end %>

    <div class="mt-3 flex flex-wrap gap-2">
      <% quick_chips.each do |chip| %>
        <button type="button"
                data-action="click->dice-form#useChip"
                data-dice-form-expression-param="<%= chip %>"
                class="rounded bg-slate-800 px-2 py-1 text-xs text-slate-300 hover:bg-slate-700"><%= chip %></button>
      <% end %>
    </div>
  <% end %>
</div>
```

- [ ] **Step 15.5: Run the spec and confirm it passes**

```
bundle exec rspec spec/components/play/dice/form_component_spec.rb
```

Expected: 8 examples, 0 failures.

- [ ] **Step 15.6: Commit**

```
git add app/components/play/dice/form_component.rb app/components/play/dice/form_component.html.erb spec/components/play/dice/form_component_spec.rb
git commit -m "Add Play::Dice::FormComponent (Phase 7.15)"
```

---

## Task 16: Build `Play::Oracle::FormComponent`

The oracle form has a question text input, a 9-option likelihood select, a small "chaos N" indicator, and an Ask submit. It carries optional `question:`, `likelihood:`, and `error:` parameters for stickiness and inline error display.

**Files:**
- Create: `app/components/play/oracle/form_component.rb`
- Create: `app/components/play/oracle/form_component.html.erb`
- Create: `spec/components/play/oracle/form_component_spec.rb`

- [ ] **Step 16.1: Write the spec**

Create `spec/components/play/oracle/form_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Play::Oracle::FormComponent, type: :component do
  include Rails.application.routes.url_helpers

  let(:user) { create(:user) }
  let(:campaign) { create(:campaign, user: user, chaos_factor: 4) }
  let(:scene)    { create(:scene, campaign: campaign) }

  it "renders a question input and an Ask button" do
    render_inline(described_class.new(scene: scene))

    expect(page).to have_field("oracle_query[question]")
    expect(page).to have_button(/ask/i)
  end

  it "posts to the oracle_queries#create route" do
    render_inline(described_class.new(scene: scene))

    expected_path = play_campaign_scene_oracle_queries_path(campaign, scene)
    expect(page.find("form")["action"]).to eq(expected_path)
  end

  it "renders a likelihood select with the 9 Mythic 2e values, defaulting to 50_50" do
    render_inline(described_class.new(scene: scene))

    %w[impossible nearly_impossible very_unlikely unlikely 50_50 likely very_likely nearly_certain certain].each do |val|
      expect(page).to have_css("select option[value='#{val}']")
    end
    expect(page.find_field("oracle_query[likelihood]").value).to eq("50_50")
  end

  it "renders the campaign's chaos factor" do
    render_inline(described_class.new(scene: scene))

    expect(page).to have_text(/chaos 4/i)
  end

  it "echoes a sticky question on error" do
    render_inline(described_class.new(scene: scene, question: "Does it open?"))

    expect(page.find_field("oracle_query[question]").value).to eq("Does it open?")
  end

  it "echoes a sticky likelihood on error" do
    render_inline(described_class.new(scene: scene, likelihood: "very_likely"))

    expect(page.find_field("oracle_query[likelihood]").value).to eq("very_likely")
  end

  it "renders the inline error when provided" do
    render_inline(described_class.new(scene: scene, error: "enter a question"))

    expect(page).to have_text("enter a question")
  end

  it "includes the oracle-form Stimulus controller hook" do
    render_inline(described_class.new(scene: scene))

    expect(page).to have_css("form[data-controller~='oracle-form']")
  end

  it "carries the scene's dom_id on its container element" do
    render_inline(described_class.new(scene: scene))

    expect(page).to have_css("##{ApplicationController.helpers.dom_id(scene, :oracle_form)}")
  end

  describe "asymmetry" do
    let(:faction) { create(:faction, campaign: campaign) }
    let(:npc)     { create(:npc, campaign: campaign) }

    before do
      create(:faction_secret, faction: faction, label: "hidden temple", content: "in the swamp")
      create(:npc_secret,     npc: npc,         label: "true identity", content: "is a doppelganger")
    end

    it "does not leak secrets of related records" do
      rendered = render_inline(described_class.new(scene: scene)).to_s
      expect(rendered).not_to leak_secrets_of(faction, npc)
    end
  end
end
```

- [ ] **Step 16.2: Run the spec and confirm it fails**

```
bundle exec rspec spec/components/play/oracle/form_component_spec.rb
```

Expected: failures referencing `uninitialized constant Play::Oracle::FormComponent`.

- [ ] **Step 16.3: Implement the component class**

Create `app/components/play/oracle/form_component.rb`:

```ruby
module Play
  module Oracle
    class FormComponent < ViewComponent::Base
      DEFAULT_LIKELIHOOD = "50_50".freeze

      LIKELIHOOD_LABELS = {
        "impossible"         => "Impossible",
        "nearly_impossible"  => "Nearly impossible",
        "very_unlikely"      => "Very unlikely",
        "unlikely"           => "Unlikely",
        "50_50"              => "50/50",
        "likely"             => "Likely",
        "very_likely"        => "Very likely",
        "nearly_certain"     => "Nearly certain",
        "certain"            => "Certain"
      }.freeze

      def initialize(scene:, question: nil, likelihood: nil, error: nil)
        @scene = scene
        @question = question
        @likelihood = likelihood || DEFAULT_LIKELIHOOD
        @error = error
      end

      attr_reader :scene, :question, :likelihood, :error

      def campaign
        scene.campaign
      end

      def container_dom_id
        helpers.dom_id(scene, :oracle_form)
      end

      def likelihood_options
        LIKELIHOOD_LABELS.map { |value, label| [ label, value ] }
      end
    end
  end
end
```

- [ ] **Step 16.4: Implement the component template**

Create `app/components/play/oracle/form_component.html.erb`:

```erb
<div id="<%= container_dom_id %>"
     class="rounded-lg border border-slate-800 bg-slate-900/40 p-4">
  <%= form_with url: helpers.play_campaign_scene_oracle_queries_path(campaign, scene),
                method: :post,
                local: false,
                html: { "data-controller": "oracle-form" } do |f| %>
    <div class="flex items-baseline justify-between">
      <p class="text-xs uppercase tracking-widest text-violet-300">Ask the oracle</p>
      <p class="text-xs text-slate-500">chaos <%= campaign.chaos_factor %></p>
    </div>

    <div class="mt-3">
      <%= f.text_field :question,
                       value: question,
                       placeholder: "e.g. Does the door open?",
                       autocomplete: "off",
                       "data-oracle-form-target": "question",
                       class: "w-full rounded bg-slate-800 px-3 py-2 text-slate-100 placeholder:text-slate-500 focus:outline-none focus:ring-1 focus:ring-violet-400" %>
    </div>

    <div class="mt-3 flex items-center gap-2">
      <%= f.select :likelihood,
                   likelihood_options,
                   { selected: likelihood },
                   { class: "flex-1 rounded bg-slate-800 px-3 py-2 text-slate-100 focus:outline-none focus:ring-1 focus:ring-violet-400" } %>
      <%= f.submit "Ask",
                   class: "rounded bg-violet-500 px-4 py-2 font-semibold text-slate-900 hover:bg-violet-400" %>
    </div>

    <% if error.present? %>
      <p class="mt-2 text-xs text-rose-400"><%= error %></p>
    <% end %>
  <% end %>
</div>
```

- [ ] **Step 16.5: Run the spec and confirm it passes**

```
bundle exec rspec spec/components/play/oracle/form_component_spec.rb
```

Expected: all examples pass.

- [ ] **Step 16.6: Commit**

```
git add app/components/play/oracle/form_component.rb app/components/play/oracle/form_component.html.erb spec/components/play/oracle/form_component_spec.rb
git commit -m "Add Play::Oracle::FormComponent (Phase 7.16)"
```

---

## Task 17: Build `Play::Scenes::InputDockComponent`

A thin wrapper that renders the two form components side-by-side at `md:` breakpoint and above.

**Files:**
- Create: `app/components/play/scenes/input_dock_component.rb`
- Create: `app/components/play/scenes/input_dock_component.html.erb`
- Create: `spec/components/play/scenes/input_dock_component_spec.rb`

- [ ] **Step 17.1: Write the spec**

Create `spec/components/play/scenes/input_dock_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Play::Scenes::InputDockComponent, type: :component do
  let(:user) { create(:user) }
  let(:campaign) { create(:campaign, user: user, chaos_factor: 5) }
  let(:scene)    { create(:scene, campaign: campaign) }

  it "renders the dice form" do
    render_inline(described_class.new(scene: scene))

    expect(page).to have_text(/roll dice/i)
    expect(page).to have_field("dice_roll[expression]")
  end

  it "renders the oracle form" do
    render_inline(described_class.new(scene: scene))

    expect(page).to have_text(/ask the oracle/i)
    expect(page).to have_field("oracle_query[question]")
  end

  describe "asymmetry" do
    let(:faction) { create(:faction, campaign: campaign) }
    let(:npc)     { create(:npc, campaign: campaign) }

    before do
      create(:faction_secret, faction: faction, label: "hidden temple", content: "in the swamp")
      create(:npc_secret,     npc: npc,         label: "true identity", content: "is a doppelganger")
    end

    it "does not leak secrets of related records" do
      rendered = render_inline(described_class.new(scene: scene)).to_s
      expect(rendered).not_to leak_secrets_of(faction, npc)
    end
  end
end
```

- [ ] **Step 17.2: Run the spec and confirm it fails**

```
bundle exec rspec spec/components/play/scenes/input_dock_component_spec.rb
```

Expected: failures referencing `uninitialized constant Play::Scenes::InputDockComponent`.

- [ ] **Step 17.3: Implement the component class**

Create `app/components/play/scenes/input_dock_component.rb`:

```ruby
module Play
  module Scenes
    class InputDockComponent < ViewComponent::Base
      def initialize(scene:)
        @scene = scene
      end

      attr_reader :scene
    end
  end
end
```

- [ ] **Step 17.4: Implement the component template**

Create `app/components/play/scenes/input_dock_component.html.erb`:

```erb
<div class="mt-8 grid gap-4 md:grid-cols-2">
  <%= render Play::Dice::FormComponent.new(scene: scene) %>
  <%= render Play::Oracle::FormComponent.new(scene: scene) %>
</div>
```

- [ ] **Step 17.5: Run the spec and confirm it passes**

```
bundle exec rspec spec/components/play/scenes/input_dock_component_spec.rb
```

Expected: all examples pass.

- [ ] **Step 17.6: Commit**

```
git add app/components/play/scenes/input_dock_component.rb app/components/play/scenes/input_dock_component.html.erb spec/components/play/scenes/input_dock_component_spec.rb
git commit -m "Add Play::Scenes::InputDockComponent (Phase 7.17)"
```

---

## Task 18: Render the input dock in `Play::Scenes::PlayComponent`

**Files:**
- Modify: `app/components/play/scenes/play_component.html.erb`
- Modify: `spec/components/play/scenes/play_component_spec.rb`

- [ ] **Step 18.1: Add a failing assertion to the play component spec**

Open `spec/components/play/scenes/play_component_spec.rb`. Add a new example inside the existing describe block (after the existing back-link example):

```ruby
it "renders the input dock (dice + oracle forms)" do
  render_inline(described_class.new(scene: scene))

  expect(page).to have_text(/roll dice/i)
  expect(page).to have_text(/ask the oracle/i)
end
```

- [ ] **Step 18.2: Run the spec and confirm the new example fails**

```
bundle exec rspec spec/components/play/scenes/play_component_spec.rb -e "input dock"
```

Expected: failure with "expected to have text 'roll dice'".

- [ ] **Step 18.3: Render the input dock in the play component template**

Edit `app/components/play/scenes/play_component.html.erb`. Insert the input dock render call right after the log component render and replace the reserved-space comment:

```erb
<div class="min-h-screen bg-slate-900 text-slate-100">
  <div class="mx-auto max-w-3xl px-4 py-8">
    <div class="mb-4">
      <%= link_to "← Back to #{campaign.name}",
                  helpers.play_campaign_path(campaign),
                  class: "text-xs uppercase tracking-widest text-slate-500 hover:text-slate-300" %>
    </div>

    <p class="text-xs uppercase tracking-widest text-slate-500"><%= campaign.name %></p>
    <h1 class="mt-1 text-3xl font-bold tracking-tight"><%= scene.title %></h1>
    <% if scene.summary.present? %>
      <p class="mt-3 text-slate-400"><%= scene.summary %></p>
    <% end %>

    <hr class="my-8 border-slate-800">

    <%= render Play::Scenes::LogComponent.new(scene: scene) %>

    <%= render Play::Scenes::InputDockComponent.new(scene: scene) %>
  </div>
</div>
```

- [ ] **Step 18.4: Run the play component spec and confirm it passes**

```
bundle exec rspec spec/components/play/scenes/play_component_spec.rb
```

Expected: all examples pass.

- [ ] **Step 18.5: Commit**

```
git add app/components/play/scenes/play_component.html.erb spec/components/play/scenes/play_component_spec.rb
git commit -m "Render input dock in Play::Scenes::PlayComponent (Phase 7.18)"
```

---

## Task 19: Wrap `Play::Scenes::LogComponent` in a Turbo Frame

Add a `<turbo-frame>` wrapper around the events list and a dom_id'd container around the empty-state placeholder so Turbo Streams can append events and remove the empty state.

**Files:**
- Modify: `app/components/play/scenes/log_component.rb`
- Modify: `app/components/play/scenes/log_component.html.erb`
- Modify: `spec/components/play/scenes/log_component_spec.rb`

- [ ] **Step 19.1: Add failing assertions**

Open `spec/components/play/scenes/log_component_spec.rb`. Add a new describe block at the top level:

```ruby
describe "turbo-frame structure" do
  it "wraps the events list in <turbo-frame id='scene_log_<id>'>" do
    render_inline(described_class.new(scene: scene))

    expect(page).to have_css("turbo-frame##{ApplicationController.helpers.dom_id(scene, :log)}")
  end

  it "gives the empty-state placeholder its own dom_id'd container" do
    render_inline(described_class.new(scene: scene))

    expect(page).to have_css("##{ApplicationController.helpers.dom_id(scene, :log_empty)}")
  end

  it "omits the empty-state container when events are present" do
    create(:event, scene: scene, kind: "narration", payload: { "text" => "An event." })

    render_inline(described_class.new(scene: scene))

    expect(page).not_to have_css("##{ApplicationController.helpers.dom_id(scene, :log_empty)}")
  end
end
```

- [ ] **Step 19.2: Run the spec and confirm the new examples fail**

```
bundle exec rspec spec/components/play/scenes/log_component_spec.rb -e "turbo-frame"
```

Expected: 3 failing examples.

- [ ] **Step 19.3: Add dom_id helpers to the component**

Edit `app/components/play/scenes/log_component.rb`. Add two reader methods:

```ruby
module Play
  module Scenes
    class LogComponent < ViewComponent::Base
      def initialize(scene:)
        @scene = scene
      end

      attr_reader :scene

      def events
        @events ||= scene.events.order(:occurred_at)
      end

      def empty?
        events.none?
      end

      def component_for(event)
        Play::Events::Component.for(event).new(event: event)
      end

      def frame_dom_id
        helpers.dom_id(scene, :log)
      end

      def empty_state_dom_id
        helpers.dom_id(scene, :log_empty)
      end
    end
  end
end
```

(If the existing class already has additional methods, leave them in place; only add the two new helpers.)

- [ ] **Step 19.4: Update the template to wrap and id-tag**

Edit `app/components/play/scenes/log_component.html.erb`:

```erb
<turbo-frame id="<%= frame_dom_id %>">
  <div class="space-y-1">
    <% if empty? %>
      <div id="<%= empty_state_dom_id %>">
        <p class="py-8 text-center text-sm text-slate-500">
          The scene is set, but nothing has happened yet.
        </p>
      </div>
    <% else %>
      <% events.each do |event| %>
        <%= render component_for(event) %>
      <% end %>
    <% end %>
  </div>
</turbo-frame>
```

- [ ] **Step 19.5: Run the log component spec and confirm everything passes**

```
bundle exec rspec spec/components/play/scenes/log_component_spec.rb
```

Expected: all examples (existing + new) pass.

- [ ] **Step 19.6: Commit**

```
git add app/components/play/scenes/log_component.rb app/components/play/scenes/log_component.html.erb spec/components/play/scenes/log_component_spec.rb
git commit -m "Wrap Play::Scenes::LogComponent in <turbo-frame> for Phase 7 streams (Phase 7.19)"
```

---

## Task 20: Add the random-event badge to `Play::Events::OracleQueryComponent`

**Files:**
- Modify: `app/components/play/events/oracle_query_component.rb`
- Modify: `app/components/play/events/oracle_query_component.html.erb`
- Modify: `spec/components/play/events/oracle_query_component_spec.rb`

- [ ] **Step 20.1: Add a failing example to the spec**

Open `spec/components/play/events/oracle_query_component_spec.rb`. Add (or update) examples:

```ruby
describe "random event badge" do
  it "renders a ✦ random event badge when random_event_triggered is true" do
    event = create(:event, :oracle_query,
                   scene: scene,
                   payload: {
                     "question" => "Q?", "answer" => "Yes", "likelihood" => "50_50",
                     "chaos" => 5, "outcome" => "yes", "roll" => 33,
                     "random_event_triggered" => true
                   })

    render_inline(described_class.new(event: event))

    expect(page).to have_text(/random event/i)
  end

  it "omits the badge when random_event_triggered is false" do
    event = create(:event, :oracle_query,
                   scene: scene,
                   payload: {
                     "question" => "Q?", "answer" => "Yes", "likelihood" => "50_50",
                     "chaos" => 5, "outcome" => "yes", "roll" => 32,
                     "random_event_triggered" => false
                   })

    render_inline(described_class.new(event: event))

    expect(page).not_to have_text(/random event/i)
  end

  it "omits the badge when random_event_triggered is absent (legacy payload)" do
    event = create(:event, :oracle_query,
                   scene: scene,
                   payload: { "question" => "Q?", "answer" => "Yes", "likelihood" => "50_50", "chaos" => 5 })

    render_inline(described_class.new(event: event))

    expect(page).not_to have_text(/random event/i)
  end
end
```

- [ ] **Step 20.2: Run the spec and confirm the new examples fail**

```
bundle exec rspec spec/components/play/events/oracle_query_component_spec.rb -e "random event"
```

Expected: at least one failure about missing badge text.

- [ ] **Step 20.3: Update the component class**

Edit `app/components/play/events/oracle_query_component.rb`. Add a reader:

```ruby
def random_event_triggered?
  event.payload["random_event_triggered"] == true
end
```

- [ ] **Step 20.4: Update the template**

Edit `app/components/play/events/oracle_query_component.html.erb`. Insert the badge inside the existing oracle card, right after the chaos/likelihood line:

```erb
<div class="my-3 rounded-r border-l-4 border-violet-500 bg-slate-800 px-3 py-2">
  <p class="text-xs uppercase tracking-widest text-violet-300">Oracle</p>
  <p class="text-slate-200"><%= question %></p>
  <p class="mt-1 text-lg font-semibold text-slate-100"><%= answer %></p>
  <% if likelihood.present? || chaos.present? %>
    <p class="text-xs text-slate-400">
      <% if likelihood.present? %><%= likelihood.tr("_", " ") %><% end %>
      <% if likelihood.present? && chaos.present? %> &middot; <% end %>
      <% if chaos.present? %>chaos <%= chaos %><% end %>
    </p>
  <% end %>
  <% if random_event_triggered? %>
    <p class="mt-2 inline-block rounded bg-violet-900/40 px-2 py-0.5 text-xs text-violet-200">
      ✦ random event
    </p>
  <% end %>
  <p class="mt-1 text-xs text-slate-600"><%= relative_time %></p>
</div>
```

- [ ] **Step 20.5: Run the spec and confirm everything passes**

```
bundle exec rspec spec/components/play/events/oracle_query_component_spec.rb
```

Expected: all examples (existing + new) pass.

- [ ] **Step 20.6: Commit**

```
git add app/components/play/events/oracle_query_component.rb app/components/play/events/oracle_query_component.html.erb spec/components/play/events/oracle_query_component_spec.rb
git commit -m "Add random-event badge to Play::Events::OracleQueryComponent (Phase 7.20)"
```

---

## Task 21: Build `Play::DiceRollsController`

**Files:**
- Create: `app/controllers/play/dice_rolls_controller.rb`
- Create: `spec/requests/play/dice_rolls_spec.rb`

- [ ] **Step 21.1: Write the request spec**

Create `spec/requests/play/dice_rolls_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Play::DiceRolls", type: :request do
  before { host! "gygaxagain.com" }

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:campaign) { create(:campaign, user: user) }
  let(:scene)    { create(:scene, campaign: campaign) }

  describe "POST /campaigns/:campaign_id/scenes/:scene_id/dice_rolls" do
    context "authenticated" do
      before { sign_in user }

      it "creates a dice_roll event with payload (HTML format)" do
        expect {
          Dice::Random.with_fixed([ 4, 5 ]) do
            post "/campaigns/#{campaign.id}/scenes/#{scene.id}/dice_rolls",
                 params: { dice_roll: { expression: "2d6+3" } }
          end
        }.to change { scene.events.count }.by(1)

        event = scene.events.last
        expect(event.kind).to eq("dice_roll")
        expect(event.payload["expression"]).to eq("2d6+3")
        expect(event.payload["result"]).to eq(12) # 4 + 5 + 3
        expect(event.payload["breakdown"]).to be_an(Array)
        expect(event.payload["rolls"]).to eq([ [ 4, 5 ], [] ])
      end

      it "responds with redirect on HTML format" do
        Dice::Random.with_fixed([ 4, 5 ]) do
          post "/campaigns/#{campaign.id}/scenes/#{scene.id}/dice_rolls",
               params: { dice_roll: { expression: "2d6" } }
        end

        expect(response).to redirect_to(play_campaign_scene_path(campaign, scene))
      end

      it "responds with Turbo Stream on turbo_stream format" do
        Dice::Random.with_fixed([ 4, 5 ]) do
          post "/campaigns/#{campaign.id}/scenes/#{scene.id}/dice_rolls",
               params: { dice_roll: { expression: "2d6" } },
               as: :turbo_stream
        end

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include('turbo-stream action="append"')
        expect(response.body).to include('turbo-stream action="remove"')
        expect(response.body).to include('turbo-stream action="replace"')
      end

      it "returns 422 and does not create on unparseable expression" do
        expect {
          post "/campaigns/#{campaign.id}/scenes/#{scene.id}/dice_rolls",
               params: { dice_roll: { expression: "1d6+wat" } },
               as: :turbo_stream
        }.not_to change { scene.events.count }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("unparseable")
      end

      it "returns 422 on empty expression" do
        post "/campaigns/#{campaign.id}/scenes/#{scene.id}/dice_rolls",
             params: { dice_roll: { expression: "" } },
             as: :turbo_stream

        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns 404 on a cross-user campaign" do
        other_campaign = create(:campaign, user: other_user)
        other_scene    = create(:scene, campaign: other_campaign)
        expect {
          post "/campaigns/#{other_campaign.id}/scenes/#{other_scene.id}/dice_rolls",
               params: { dice_roll: { expression: "1d6" } }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "returns 404 on a cross-campaign scene" do
        other_campaign = create(:campaign, user: user)
        scene_in_other = create(:scene, campaign: other_campaign)
        expect {
          post "/campaigns/#{campaign.id}/scenes/#{scene_in_other.id}/dice_rolls",
               params: { dice_roll: { expression: "1d6" } }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "unauthenticated" do
      it "redirects to sign-in" do
        post "/campaigns/#{campaign.id}/scenes/#{scene.id}/dice_rolls",
             params: { dice_roll: { expression: "1d6" } }

        expect(response).to have_http_status(:found)
        expect(response.location).to include("/users/sign_in")
      end
    end
  end
end
```

- [ ] **Step 21.2: Run the spec and confirm it fails**

```
bundle exec rspec spec/requests/play/dice_rolls_spec.rb
```

Expected: failures referencing `uninitialized constant Play::DiceRollsController`.

- [ ] **Step 21.3: Implement the controller**

Create `app/controllers/play/dice_rolls_controller.rb`:

```ruby
module Play
  class DiceRollsController < ::ApplicationController
    before_action :load_scene

    def create
      expression = params.require(:dice_roll).permit(:expression).fetch(:expression, "").to_s

      begin
        result = Dice::Roll.call(expression)
      rescue Dice::ParseError => e
        return respond_with_error(expression: expression, message: e.message)
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
        f.turbo_stream { render turbo_stream: stream_success(event) }
        f.html { redirect_to play_campaign_scene_path(@scene.campaign, @scene) }
      end
    end

    private

    def load_scene
      @scene = current_user
                 .campaigns
                 .find(params[:campaign_id])
                 .scenes
                 .find(params[:scene_id])
    end

    def stream_success(event)
      [
        turbo_stream.append(
          helpers.dom_id(@scene, :log),
          Play::Events::Component.for(event).new(event: event)
        ),
        turbo_stream.remove(helpers.dom_id(@scene, :log_empty)),
        turbo_stream.replace(
          helpers.dom_id(@scene, :dice_form),
          Play::Dice::FormComponent.new(scene: @scene)
        )
      ]
    end

    def respond_with_error(expression:, message:)
      respond_to do |f|
        f.turbo_stream do
          render turbo_stream: turbo_stream.replace(
                   helpers.dom_id(@scene, :dice_form),
                   Play::Dice::FormComponent.new(scene: @scene, expression: expression, error: message)
                 ),
                 status: :unprocessable_content
        end
        f.html do
          redirect_to play_campaign_scene_path(@scene.campaign, @scene),
                      alert: message
        end
      end
    end
  end
end
```

- [ ] **Step 21.4: Run the spec and confirm it passes**

```
bundle exec rspec spec/requests/play/dice_rolls_spec.rb
```

Expected: all examples pass.

- [ ] **Step 21.5: Commit**

```
git add app/controllers/play/dice_rolls_controller.rb spec/requests/play/dice_rolls_spec.rb
git commit -m "Add Play::DiceRollsController with Turbo Stream broadcast (Phase 7.21)"
```

---

## Task 22: Build `Play::OracleQueriesController`

**Files:**
- Create: `app/controllers/play/oracle_queries_controller.rb`
- Create: `spec/requests/play/oracle_queries_spec.rb`

- [ ] **Step 22.1: Write the request spec**

Create `spec/requests/play/oracle_queries_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Play::OracleQueries", type: :request do
  before { host! "gygaxagain.com" }

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:campaign) { create(:campaign, user: user, chaos_factor: 5) }
  let(:scene)    { create(:scene, campaign: campaign) }

  describe "POST /campaigns/:campaign_id/scenes/:scene_id/oracle_queries" do
    context "authenticated" do
      before { sign_in user }

      it "creates an oracle_query event with full payload" do
        expect {
          Mythic::Random.with_fixed_d100([ 32 ]) do
            post "/campaigns/#{campaign.id}/scenes/#{scene.id}/oracle_queries",
                 params: { oracle_query: { question: "Does it open?", likelihood: "50_50" } }
          end
        }.to change { scene.events.count }.by(1)

        event = scene.events.last
        expect(event.kind).to eq("oracle_query")
        expect(event.payload["question"]).to eq("Does it open?")
        expect(event.payload["answer"]).to eq("Yes")
        expect(event.payload["outcome"]).to eq("yes")
        expect(event.payload["likelihood"]).to eq("50_50")
        expect(event.payload["chaos"]).to eq(5)
        expect(event.payload["roll"]).to eq(32)
        expect(event.payload["random_event_triggered"]).to eq(false)
      end

      it "uses the campaign's chaos factor (not a query param)" do
        campaign.update!(chaos_factor: 7)

        Mythic::Random.with_fixed_d100([ 50 ]) do
          post "/campaigns/#{campaign.id}/scenes/#{scene.id}/oracle_queries",
               params: { oracle_query: { question: "q", likelihood: "50_50", chaos_factor: 1 } }
        end

        expect(scene.events.last.payload["chaos"]).to eq(7)
      end

      it "sets random_event_triggered=true when the trigger rule fires" do
        Mythic::Random.with_fixed_d100([ 33 ]) do
          # roll=33 doubled-digit; leading 3 <= chaos 5 -> trigger
          post "/campaigns/#{campaign.id}/scenes/#{scene.id}/oracle_queries",
               params: { oracle_query: { question: "q", likelihood: "50_50" } }
        end

        expect(scene.events.last.payload["random_event_triggered"]).to eq(true)
      end

      it "defaults likelihood to 50_50 when not provided" do
        Mythic::Random.with_fixed_d100([ 50 ]) do
          post "/campaigns/#{campaign.id}/scenes/#{scene.id}/oracle_queries",
               params: { oracle_query: { question: "q" } }
        end

        expect(scene.events.last.payload["likelihood"]).to eq("50_50")
      end

      it "responds with Turbo Stream on turbo_stream format" do
        Mythic::Random.with_fixed_d100([ 50 ]) do
          post "/campaigns/#{campaign.id}/scenes/#{scene.id}/oracle_queries",
               params: { oracle_query: { question: "q", likelihood: "likely" } },
               as: :turbo_stream
        end

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include('turbo-stream action="append"')
      end

      it "returns 422 on a blank question" do
        expect {
          post "/campaigns/#{campaign.id}/scenes/#{scene.id}/oracle_queries",
               params: { oracle_query: { question: "  ", likelihood: "50_50" } },
               as: :turbo_stream
        }.not_to change { scene.events.count }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("enter a question")
      end

      it "returns 404 on a cross-user campaign" do
        other_campaign = create(:campaign, user: other_user)
        other_scene    = create(:scene, campaign: other_campaign)
        expect {
          post "/campaigns/#{other_campaign.id}/scenes/#{other_scene.id}/oracle_queries",
               params: { oracle_query: { question: "q", likelihood: "50_50" } }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "unauthenticated" do
      it "redirects to sign-in" do
        post "/campaigns/#{campaign.id}/scenes/#{scene.id}/oracle_queries",
             params: { oracle_query: { question: "q", likelihood: "50_50" } }

        expect(response).to have_http_status(:found)
        expect(response.location).to include("/users/sign_in")
      end
    end
  end
end
```

- [ ] **Step 22.2: Run the spec and confirm it fails**

```
bundle exec rspec spec/requests/play/oracle_queries_spec.rb
```

Expected: failures referencing `uninitialized constant Play::OracleQueriesController`.

- [ ] **Step 22.3: Implement the controller**

Create `app/controllers/play/oracle_queries_controller.rb`:

```ruby
module Play
  class OracleQueriesController < ::ApplicationController
    before_action :load_scene

    def create
      attrs = params.require(:oracle_query).permit(:question, :likelihood)
      question = attrs.fetch(:question, "").to_s.strip
      likelihood = attrs.fetch(:likelihood, Play::Oracle::FormComponent::DEFAULT_LIKELIHOOD).to_s
      likelihood = Play::Oracle::FormComponent::DEFAULT_LIKELIHOOD if likelihood.blank?

      if question.blank?
        return respond_with_error(
          question: question,
          likelihood: likelihood,
          message: "enter a question"
        )
      end

      result = ::Mythic::Oracle.call(
        question: question,
        likelihood: likelihood,
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
        f.turbo_stream { render turbo_stream: stream_success(event) }
        f.html { redirect_to play_campaign_scene_path(@scene.campaign, @scene) }
      end
    end

    private

    def load_scene
      @scene = current_user
                 .campaigns
                 .find(params[:campaign_id])
                 .scenes
                 .find(params[:scene_id])
    end

    def stream_success(event)
      [
        turbo_stream.append(
          helpers.dom_id(@scene, :log),
          Play::Events::Component.for(event).new(event: event)
        ),
        turbo_stream.remove(helpers.dom_id(@scene, :log_empty)),
        turbo_stream.replace(
          helpers.dom_id(@scene, :oracle_form),
          Play::Oracle::FormComponent.new(scene: @scene)
        )
      ]
    end

    def respond_with_error(question:, likelihood:, message:)
      respond_to do |f|
        f.turbo_stream do
          render turbo_stream: turbo_stream.replace(
                   helpers.dom_id(@scene, :oracle_form),
                   Play::Oracle::FormComponent.new(
                     scene: @scene, question: question, likelihood: likelihood, error: message
                   )
                 ),
                 status: :unprocessable_content
        end
        f.html do
          redirect_to play_campaign_scene_path(@scene.campaign, @scene),
                      alert: message
        end
      end
    end
  end
end
```

- [ ] **Step 22.4: Run the spec and confirm it passes**

```
bundle exec rspec spec/requests/play/oracle_queries_spec.rb
```

Expected: all examples pass.

- [ ] **Step 22.5: Commit**

```
git add app/controllers/play/oracle_queries_controller.rb spec/requests/play/oracle_queries_spec.rb
git commit -m "Add Play::OracleQueriesController with Turbo Stream broadcast (Phase 7.22)"
```

---

## Task 23: Create the `dice-form` Stimulus controller

**Files:**
- Create: `app/javascript/controllers/dice_form_controller.js`
- Modify: `app/javascript/application.js`

- [ ] **Step 23.1: Implement the controller**

Create `app/javascript/controllers/dice_form_controller.js`:

```javascript
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
```

- [ ] **Step 23.2: Register the controller**

Edit `app/javascript/application.js` so the new controller is registered. The file currently looks like:

```javascript
import { Application } from "@hotwired/stimulus"
import FlashController from "./controllers/flash_controller"

const application = Application.start()
application.register("flash", FlashController)
```

Update it to:

```javascript
import { Application } from "@hotwired/stimulus"
import FlashController from "./controllers/flash_controller"
import DiceFormController from "./controllers/dice_form_controller"

const application = Application.start()
application.register("flash", FlashController)
application.register("dice-form", DiceFormController)
```

- [ ] **Step 23.3: Sanity-check the build**

```
bun run build
```

(Or whichever build script `package.json` exposes; the project uses `jsbundling-rails` with `bun`.) Expected: bundles to `app/assets/builds/application.js` with no errors.

- [ ] **Step 23.4: Commit**

```
git add app/javascript/controllers/dice_form_controller.js app/javascript/application.js app/assets/builds/application.js
git commit -m "Add dice-form Stimulus controller for quick-roll chips (Phase 7.23)"
```

(If `app/assets/builds/application.js` is gitignored in this project, omit it from the add — check `.gitignore` first.)

---

## Task 24: Create the `oracle-form` Stimulus controller

**Files:**
- Create: `app/javascript/controllers/oracle_form_controller.js`
- Modify: `app/javascript/application.js`

- [ ] **Step 24.1: Implement the controller**

Create `app/javascript/controllers/oracle_form_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["question"]
}
```

The oracle form's reset on success is handled by the Turbo Stream `replace` of the entire form container — no JS-level reset code is needed in Phase 7. The controller exists primarily as a hook for Phase 8 / future enhancements; we register it now so the form's `data-controller` attribute resolves without console warnings.

- [ ] **Step 24.2: Register the controller**

Edit `app/javascript/application.js`:

```javascript
import { Application } from "@hotwired/stimulus"
import FlashController from "./controllers/flash_controller"
import DiceFormController from "./controllers/dice_form_controller"
import OracleFormController from "./controllers/oracle_form_controller"

const application = Application.start()
application.register("flash", FlashController)
application.register("dice-form", DiceFormController)
application.register("oracle-form", OracleFormController)
```

- [ ] **Step 24.3: Rebuild JS**

```
bun run build
```

- [ ] **Step 24.4: Commit**

```
git add app/javascript/controllers/oracle_form_controller.js app/javascript/application.js
git commit -m "Add oracle-form Stimulus controller placeholder (Phase 7.24)"
```

---

## Task 25: Wire Selenium-headless-Chrome for system specs

**Files:**
- Modify: `Gemfile`
- Modify: `Gemfile.lock` (regenerated)
- Modify: `spec/support/capybara.rb`

- [ ] **Step 25.1: Add `selenium-webdriver` to the test group**

Edit `Gemfile`. In the `group :test do` block, add:

```ruby
group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "webmock"
end
```

- [ ] **Step 25.2: Install the gem**

```
bundle install
```

- [ ] **Step 25.3: Register and select the headless driver**

Edit `spec/support/capybara.rb` to register `:selenium_chrome_headless` as the JavaScript driver and pin sensible defaults:

```ruby
require "capybara/rails"
require "capybara/rspec"
require "selenium-webdriver"

Capybara.default_host = "http://gygaxagain.com"
Capybara.app_host = "http://gygaxagain.com"
Capybara.always_include_port = true
Capybara.server = :puma, { Silent: true }

Capybara.register_driver :selenium_chrome_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless=new")
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-gpu")
  options.add_argument("--window-size=1400,1000")
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

Capybara.javascript_driver = :selenium_chrome_headless

# Per-example: examples tagged with js: true use the JS driver.
RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by(:rack_test)
  end

  config.before(:each, type: :system, js: true) do
    driven_by(Capybara.javascript_driver)
  end
end
```

- [ ] **Step 25.4: Sanity-check by running a non-JS system spec**

```
bundle exec rspec spec/system/phase_6_play_surface_spec.rb
```

Expected: still green (uses rack_test by default, unaffected by the new JS registration).

- [ ] **Step 25.5: Commit**

```
git add Gemfile Gemfile.lock spec/support/capybara.rb
git commit -m "Wire selenium-webdriver and js: true driver for system specs (Phase 7.25)"
```

---

## Task 26: Write the Phase 7 system spec (end-to-end)

A single `js: true` system spec that exercises the full flow: sign in, navigate to a scene, roll dice (event appears), ask oracle (event appears with random-event badge), switch to admin, bump chaos, confirm chaos label updates in play.

**Files:**
- Create: `spec/system/phase_7_play_mechanics_spec.rb`

- [ ] **Step 26.1: Write the spec**

Create `spec/system/phase_7_play_mechanics_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Phase 7: dice + oracle play mechanics", type: :system, js: true do
  let(:user) { create(:user, password: "Password!1") }
  let!(:campaign) { create(:campaign, user: user, name: "Curse", chaos_factor: 5) }
  let!(:scene)    { create(:scene, campaign: campaign, title: "Tavern at Dusk", summary: "Rainy.") }

  before do
    Capybara.app_host = "http://gygaxagain.com"
  end

  it "rolls dice, asks the oracle, and adjusts chaos from admin" do
    # Sign in on the apex domain.
    visit "/users/sign_in"
    fill_in "Email", with: user.email
    fill_in "Password", with: "Password!1"
    click_button "Log in"

    # Navigate to the scene's play page.
    Capybara.app_host = "http://gygaxagain.com"
    visit play_campaign_scene_path(campaign, scene)
    expect(page).to have_text("Tavern at Dusk")
    expect(page).to have_text(/the scene is set/i)

    # Roll dice with a stubbed random roll.
    Dice::Random.with_fixed([ 15 ]) do
      fill_in "dice_roll[expression]", with: "1d20"
      click_button "Roll"
    end

    expect(page).to have_text("1d20")
    expect(page).to have_text("Result: 15")
    expect(page).not_to have_text(/the scene is set/i)

    # Ask the oracle with a roll that triggers a random event (33 with chaos=5).
    Mythic::Random.with_fixed_d100([ 33 ]) do
      fill_in "oracle_query[question]", with: "Does the door open?"
      select "Likely", from: "oracle_query[likelihood]"
      click_button "Ask"
    end

    expect(page).to have_text("Does the door open?")
    expect(page).to have_text(/random event/i)

    # Switch to admin and bump chaos.
    Capybara.app_host = "http://admin.gygaxagain.com"
    visit "/campaigns/#{campaign.id}"
    expect(page).to have_text(/chaos factor/i)
    find("button[data-direction='up']").click

    expect(campaign.reload.chaos_factor).to eq(6)

    # Back to play; confirm the oracle form's chaos label updated.
    Capybara.app_host = "http://gygaxagain.com"
    visit play_campaign_scene_path(campaign, scene)
    expect(page).to have_text("chaos 6")
  end
end
```

Notes on this spec:
- `js: true` selects the Selenium headless-Chrome driver.
- `Capybara.app_host` reassignment between visits is the v1 idiom for crossing subdomains in the same example. The Phase 2 spec helpers may have refined this; if so, defer to them.
- `Dice::Random.with_fixed` / `Mythic::Random.with_fixed_d100` set module-level state in the spec process (per Tasks 4 and 9). Puma serves the form-submit request on a worker thread in the same process, so the stubs DO apply to requests made via the headless browser. Tests run serially under `use_transactional_fixtures = true`, so cross-example bleeding isn't a concern.

- [ ] **Step 26.2: Run the spec**

```
bundle exec rspec spec/system/phase_7_play_mechanics_spec.rb
```

Expected: passes. If headless Chrome isn't available on the test machine, the spec will error with a driver init failure — install Chrome (macOS: `brew install --cask google-chrome`) and re-run.

If the random-stub-across-server-thread assumption proves wrong (the stub is set in the spec thread, but Puma serves requests on a different thread), the spec will see real random results. Two fallbacks:
- Promote the stub setup to `before(:each)` with explicit thread propagation, OR
- Replace the stubs with WebMock-style request interception. Simplest: use `allow(SecureRandom).to receive(:random_number).and_return(...)` if the controller path is fully in-thread, OR run system tests with `Capybara.server = :puma, { Threads: "0:1" }` and use `config.before { ActiveRecord::Base.connection_pool.disconnect! }`-style hooks. The plan settles this empirically on first run.

- [ ] **Step 26.3: Commit**

```
git add spec/system/phase_7_play_mechanics_spec.rb
git commit -m "Add Phase 7 end-to-end system spec (Phase 7.26)"
```

---

## Task 27: Add Lookbook previews

**Files:**
- Create: `spec/components/previews/play/dice/form_component_preview.rb`
- Create: `spec/components/previews/play/oracle/form_component_preview.rb`
- Create: `spec/components/previews/play/scenes/input_dock_component_preview.rb`
- Modify: `spec/components/previews/play/events/oracle_query_component_preview.rb`
- Create: `spec/components/previews/admin/campaigns/chaos_factor_component_preview.rb`

- [ ] **Step 27.1: Create the dice form preview**

Create `spec/components/previews/play/dice/form_component_preview.rb`:

```ruby
module Play
  module Dice
    class FormComponentPreview < Lookbook::Preview
      def default
        scene = preview_scene
        render Play::Dice::FormComponent.new(scene: scene)
      end

      def with_sticky_value
        scene = preview_scene
        render Play::Dice::FormComponent.new(scene: scene, expression: "4d6kh3")
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

- [ ] **Step 27.2: Create the oracle form preview**

Create `spec/components/previews/play/oracle/form_component_preview.rb`:

```ruby
module Play
  module Oracle
    class FormComponentPreview < Lookbook::Preview
      def default
        scene = preview_scene(chaos: 5)
        render Play::Oracle::FormComponent.new(scene: scene)
      end

      def with_sticky_value
        scene = preview_scene(chaos: 5)
        render Play::Oracle::FormComponent.new(
          scene: scene,
          question: "Does the door open?",
          likelihood: "likely"
        )
      end

      def with_error
        scene = preview_scene(chaos: 5)
        render Play::Oracle::FormComponent.new(
          scene: scene,
          question: "",
          error: "enter a question"
        )
      end

      def with_high_chaos
        scene = preview_scene(chaos: 9)
        render Play::Oracle::FormComponent.new(scene: scene)
      end

      private

      def preview_scene(chaos:)
        campaign = Campaign.new(name: "Preview Campaign", chaos_factor: chaos)
        Scene.new(id: 1, title: "Preview Scene", campaign: campaign)
      end
    end
  end
end
```

- [ ] **Step 27.3: Create the input dock preview**

Create `spec/components/previews/play/scenes/input_dock_component_preview.rb`:

```ruby
module Play
  module Scenes
    class InputDockComponentPreview < Lookbook::Preview
      def default
        campaign = Campaign.new(name: "Preview Campaign", chaos_factor: 5)
        scene = Scene.new(id: 1, title: "Preview Scene", campaign: campaign)
        render Play::Scenes::InputDockComponent.new(scene: scene)
      end
    end
  end
end
```

- [ ] **Step 27.4: Extend the oracle event preview**

Open `spec/components/previews/play/events/oracle_query_component_preview.rb`. Add a new example after the existing ones:

```ruby
def with_random_event
  scene = Scene.new(id: 1, title: "Preview Scene",
                    campaign: Campaign.new(name: "Preview", chaos_factor: 5))
  event = Event.new(
    scene: scene,
    kind: "oracle_query",
    occurred_at: Time.current,
    payload: {
      "question" => "Does the door open?",
      "answer" => "Yes",
      "likelihood" => "50_50",
      "chaos" => 5,
      "outcome" => "yes",
      "roll" => 33,
      "random_event_triggered" => true
    }
  )
  render Play::Events::OracleQueryComponent.new(event: event)
end
```

(If the existing preview file has a `default` example, model the new one on its shape — keep field names and `Event.new` initialization consistent.)

- [ ] **Step 27.5: Create the chaos factor preview**

Create `spec/components/previews/admin/campaigns/chaos_factor_component_preview.rb`:

```ruby
module Admin
  module Campaigns
    class ChaosFactorComponentPreview < Lookbook::Preview
      def mid_range
        campaign = Campaign.new(id: 1, name: "Preview", chaos_factor: 5)
        render Admin::Campaigns::ChaosFactorComponent.new(campaign: campaign)
      end

      def at_minimum
        campaign = Campaign.new(id: 1, name: "Preview", chaos_factor: 1)
        render Admin::Campaigns::ChaosFactorComponent.new(campaign: campaign)
      end

      def at_maximum
        campaign = Campaign.new(id: 1, name: "Preview", chaos_factor: 9)
        render Admin::Campaigns::ChaosFactorComponent.new(campaign: campaign)
      end
    end
  end
end
```

- [ ] **Step 27.6: Sanity-check Lookbook loads the previews**

```
bin/rails server -p 3000
```

In a separate terminal, open `http://localhost:3000/lookbook` and confirm each new preview renders without errors. Stop the server.

(No commit-required test step here — previews are dev-only.)

- [ ] **Step 27.7: Commit**

```
git add spec/components/previews/play/dice/form_component_preview.rb \
        spec/components/previews/play/oracle/form_component_preview.rb \
        spec/components/previews/play/scenes/input_dock_component_preview.rb \
        spec/components/previews/play/events/oracle_query_component_preview.rb \
        spec/components/previews/admin/campaigns/chaos_factor_component_preview.rb
git commit -m "Add Phase 7 Lookbook previews (Phase 7.27)"
```

---

## Task 28: Final polish — RuboCop, erb_lint, full suite

- [ ] **Step 28.1: Run RuboCop on changed files**

```
bundle exec rubocop --autocorrect-all \
  app/services app/controllers/admin/chaos_factors_controller.rb \
  app/controllers/play/dice_rolls_controller.rb \
  app/controllers/play/oracle_queries_controller.rb \
  app/components/play/dice app/components/play/oracle \
  app/components/play/scenes/input_dock_component.rb \
  app/components/admin/campaigns/chaos_factor_component.rb \
  spec/services spec/components/play/dice spec/components/play/oracle \
  spec/components/play/scenes/input_dock_component_spec.rb \
  spec/components/admin/campaigns/chaos_factor_component_spec.rb \
  spec/requests/play/dice_rolls_spec.rb \
  spec/requests/play/oracle_queries_spec.rb \
  spec/requests/admin/chaos_factors_spec.rb \
  spec/system/phase_7_play_mechanics_spec.rb
```

Expected: 0 offenses (or only auto-corrected ones).

- [ ] **Step 28.2: Run erb_lint on changed templates**

```
bundle exec erb_lint \
  app/components/play/dice/form_component.html.erb \
  app/components/play/oracle/form_component.html.erb \
  app/components/play/scenes/input_dock_component.html.erb \
  app/components/play/scenes/log_component.html.erb \
  app/components/play/scenes/play_component.html.erb \
  app/components/play/events/oracle_query_component.html.erb \
  app/components/admin/campaigns/chaos_factor_component.html.erb \
  app/components/admin/campaigns/show_component.html.erb
```

Expected: 0 offenses.

- [ ] **Step 28.3: Run Brakeman**

```
bundle exec brakeman -q
```

Expected: 0 new warnings (existing warnings unchanged).

- [ ] **Step 28.4: Run the full RSpec suite**

```
bundle exec rspec
```

Expected: all green. The system spec adds ~30s to suite time (Chrome boot); plan for it.

- [ ] **Step 28.5: Refresh model annotations**

```
bundle exec annotaterb models
```

This is a no-op if Task 1 already covered it; otherwise it refreshes any annotation drift.

- [ ] **Step 28.6: Commit any lint / annotation fixes**

If RuboCop / erb_lint / annotaterb produced changes, commit them:

```
git add -A
git commit -m "Lint and annotation refresh for Phase 7 (Phase 7.28)"
```

If nothing changed, skip this step.

- [ ] **Step 28.7: Close Phase 7**

Open issue [#8](https://github.com/barriault/gygaxagain/issues/8). In the issue body, fill in the "Implementation plan" line with the path to this plan file. Push `main` to origin.

```
git push origin main
```

(If Phase 7 work was done on a branch, open a PR against `main` instead and tag the spec + plan in the PR description.)

---

## Self-review notes

This plan implements every requirement in [`docs/superpowers/specs/2026-05-14-v2-phase-7-dice-and-mythic-oracle-design.md`](../specs/2026-05-14-v2-phase-7-dice-and-mythic-oracle-design.md):

- **`Dice::Roll` parses `2d6+3`, `1d20-1`** → Task 3 (parser), Task 5 (entry point).
- **Returns a structured result** → Task 5 returns `Dice::Roll::Result(expression, total, breakdown, rolls)`.
- **Includes `kh/kl`** → Task 3 grammar, Task 5 evaluator.
- **`Mythic::Oracle` accepts question + likelihood + chaos factor** → Task 10 entry point signature.
- **Returns yes / no / exceptional / random_event** → Task 10 Result has `:outcome ∈ {exceptional_yes, yes, no, exceptional_no}` plus `random_event_triggered`.
- **Surfaced in play UI; clicking creates an Event; Turbo Stream broadcast** → Tasks 15-18 (forms + dock), Tasks 21-22 (controllers with Turbo Stream responses).
- **Chaos factor per-campaign, adjustable from admin** → Task 1 (column), Tasks 12-14 (admin UI), Task 13 (clamping controller).
- **Tests cover dice edge cases and oracle outcome tables** → Tasks 3, 5, 8, 10 cover edge cases, every band, every chaos × doubled-digit roll.

Asymmetry guards are added to every player-facing component (Tasks 15, 16, 17). Admin chaos panel intentionally lacks the asymmetry guard (admin is narrator-side per Phase 0).

Selenium is wired in Task 25 with a fallback to rack_test for non-JS examples; the Phase 6 system spec stays on rack_test (still green). Task 26 is the first JS-tagged system example in v2.

No placeholders remain. Every step has exact code, exact paths, and exact commands. Tasks decompose into 4-7 bite-sized steps each (failing test → confirm-failure → impl → confirm-pass → commit).
