# v2 Phase 8 — Narrator integration + streaming: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the streaming-narration play loop. Player submits an action, narration response streams in token-by-token, llm_calls row captures the full prompt/response, asymmetry guaranteed structurally because the prompt is built from `Player::*ViewModel` only. Admin "End scene" closes a scene and enqueues a structured-output bookkeeper audit stored in a new `scene_audits` table.

**Architecture:** A new `Narrator::PromptBuilder` (under `app/lib/narrator/`) is a pure function over `Player::*` ViewModels that returns a `Narrator::Prompt` with three system blocks (rules, campaign+roster, scene context) and one user message. The `Llm::Providers::Anthropic` adapter grows a `#call_streaming` method using the SDK's `client.messages.stream(...).text` Enumerable + `accumulated_message`, plus first-class `cache_breakpoints:` translated into `cache_control: { type: "ephemeral", ttl: ... }` markers on the indicated system blocks. A new `NarrationJob` in Solid Queue orchestrates the stream, batches chunks (~80ms or ~25 bytes), and broadcasts `turbo_stream.replace` to a per-`(scene, user)` channel. Player input is a fifth `Event` kind (`player_action`); each submit creates two events in a transaction (`player_action` then `narration` placeholder) and enqueues `NarrationJob`. Scene close adds `closed_at` on Scene + a `scene_audits` row populated by `SceneAuditJob` (synchronous Sonnet call, JSON output, structured verdict).

**Tech Stack:** Rails 8.1 · ViewComponent · Turbo Streams + ActionCable · Stimulus · Tailwind CSS · Lookbook · RSpec · Capybara + `selenium-webdriver` · Solid Queue · `anthropic` 1.41 SDK · WebMock.

**Spec:** [`docs/superpowers/specs/2026-05-14-v2-phase-8-narrator-streaming-design.md`](../specs/2026-05-14-v2-phase-8-narrator-streaming-design.md).

**Issue:** [#9](https://github.com/barriault/gygaxagain/issues/9).

---

## File structure

**Schema (Tasks 1-4):**
- `app/models/event.rb` — modified (add `player_action` to `KINDS`)
- `db/migrate/<ts>_add_closed_at_to_scenes.rb` — new
- `db/migrate/<ts>_create_scene_audits.rb` — new
- `app/models/scene.rb` — modified (`closed?`, `has_one :audit`)
- `app/models/scene_audit.rb` — new
- `app/models/campaign.rb` — modified (`has_many :scene_audits, through: :scenes, source: :audit`)

**ViewModels (Tasks 5-8):**
- `app/view_models/player/campaign_view_model.rb` — new
- `app/view_models/player/scene_view_model.rb` — new
- `app/view_models/player/event_view_model.rb` — new
- `app/view_models/narrator/event_view_model.rb` — new
- `app/view_models/narrator/scene_audit_view_model.rb` — new

**LLM streaming layer (Tasks 9-13):**
- `app/lib/llm/providers/anthropic.rb` — modified (extract `build_request_body`, add `normalize_system`, `ttl_to_anthropic`, `cache_breakpoints:` on `#call`, new `#call_streaming`)
- `app/lib/llm/call.rb` — modified (extract `compute_cost_cents`, add `cache_breakpoints:` / `cache_ttl:` to `execute`, new `execute_streaming`)
- `app/lib/llm/provider.rb` — modified (add `:bookkeeper_audit` purpose)

**Narrator namespace (Tasks 14-17):**
- `app/lib/narrator/prompt.rb` — new (`Data.define` shape)
- `app/lib/narrator/system_prompt.rb` — new (rules text constant)
- `app/lib/narrator/prompt_builder.rb` — new
- `app/lib/narrator/audit_system_prompt.rb` — new (audit rules + JSON schema)
- `app/lib/narrator/audit_prompt_builder.rb` — new

**Test infrastructure (Task 18):**
- `spec/support/anthropic_streaming.rb` — new
- `spec/support/turbo_streams.rb` — new

**Jobs (Tasks 19-20):**
- `app/jobs/narration_job.rb` — new
- `app/jobs/scene_audit_job.rb` — new

**Play side UI (Tasks 21-25):**
- `app/components/play/narration/form_component.{rb,html.erb}` — new
- `app/components/play/events/player_action_component.{rb,html.erb}` — new
- `app/components/play/events/component.rb` — modified (add `player_action` to REGISTRY)
- `app/components/play/events/narration_component.{rb,html.erb}` — modified (status branches)
- `app/controllers/play/narrations_controller.rb` — new
- `config/routes/play.rb` — modified (nested `narrations`)
- `app/components/play/scenes/play_component.html.erb` — modified (render form, scroll wrapper)

**Stimulus controllers (Task 26):**
- `app/javascript/controllers/narration_form_controller.js` — new
- `app/javascript/controllers/scene_log_scroll_controller.js` — new
- `app/javascript/application.js` — modified (register both)

**Admin scene-close + audit (Tasks 27-29):**
- `app/controllers/admin/scene_closures_controller.rb` — new
- `app/components/admin/scenes/close_button_component.{rb,html.erb}` — new
- `app/components/admin/scenes/row_component.{rb,html.erb}` — modified (close button + audit link)
- `app/controllers/admin/scene_audits_controller.rb` — new
- `app/components/admin/scene_audits/show_component.{rb,html.erb}` — new
- `config/routes/admin.rb` — modified (nested `scene_closures`, `scene_audits`)

**System spec (Task 30):**
- `spec/system/phase_8_narrator_streaming_spec.rb` — new

**Lookbook previews (Task 31):**
- `spec/components/previews/play/narration/form_component_preview.rb` — new
- `spec/components/previews/play/events/player_action_component_preview.rb` — new
- `spec/components/previews/play/events/narration_component_preview.rb` — modified (add streaming/errored examples)
- `spec/components/previews/admin/scenes/close_button_component_preview.rb` — new
- `spec/components/previews/admin/scene_audits/show_component_preview.rb` — new

**Final polish (Task 32):**
- RuboCop, erb_lint, annotaterb refresh, full RSpec + Brakeman.

---

## Sequencing notes

- Stages run roughly: schema → ViewModels → Llm streaming refactor + new method → Narrator namespace → test helpers → jobs → play UI → Stimulus → admin scene-close / audit → system spec → previews → polish.
- Each task is one feature slice (TDD: failing test → impl → green → commit). Where a task touches multiple files of the same component (`.rb` + `.html.erb` + spec), all are part of the same commit.
- Run only the affected spec file in each step. The system spec (Task 30) and the final polish step (Task 32) run the full suite.
- Branch is `main` per existing convention (Phase 7 also committed directly to main with phase-numbered commit messages).
- The `anthropic` 1.41 SDK exposes `client.messages.stream(params).text.each { |delta| ... }` (an Enumerable of String deltas) plus `stream.accumulated_message` for the final `Anthropic::Models::Message` (with `id`, `usage`, `content`). The plan uses this clean API rather than the lower-level event loop.
- The cache TTL enum is `Anthropic::CacheControlEphemeral::TTL` with values `:"5m"` and `:"1h"`. Sending `{ type: "ephemeral", ttl: "5m" }` in the request body works (the SDK enum coerces strings).
- Existing tests for `Llm::Providers::Anthropic#call` and `Llm::Call.execute` MUST stay green after the refactor in Tasks 9-12; the refactor is invisible from the outside.

---

## Task 1: Add `player_action` to `Event::KINDS`

**Files:**
- Modify: `app/models/event.rb`
- Modify: `spec/models/event_spec.rb`

- [ ] **Step 1.1: Write the failing model spec**

Add to `spec/models/event_spec.rb` inside the existing `RSpec.describe Event do ... end` block, alongside the existing `describe "kind" do ... end` group:

```ruby
describe "kind enum" do
  it "accepts player_action as a valid kind" do
    scene = create(:scene)
    event = scene.events.build(kind: "player_action", payload: { "text" => "hi" })
    expect(event).to be_valid
  end

  it "preserves the existing four kinds" do
    expect(Event::KINDS).to include("narration", "dice_roll", "oracle_query", "scene_transition")
  end

  it "lists exactly the five expected kinds" do
    expect(Event::KINDS).to match_array(%w[narration player_action dice_roll oracle_query scene_transition])
  end
end
```

- [ ] **Step 1.2: Run the spec and confirm failure**

```
bundle exec rspec spec/models/event_spec.rb -e "kind enum"
```

Expected: `player_action` rejected by enum / KINDS does not include it.

- [ ] **Step 1.3: Update `Event::KINDS`**

Edit `app/models/event.rb`. Change:

```ruby
KINDS = %w[narration dice_roll oracle_query scene_transition].freeze
```

to:

```ruby
KINDS = %w[narration player_action dice_roll oracle_query scene_transition].freeze
```

- [ ] **Step 1.4: Run the spec and confirm pass**

```
bundle exec rspec spec/models/event_spec.rb
```

Expected: 0 failures.

- [ ] **Step 1.5: Commit**

```
git add app/models/event.rb spec/models/event_spec.rb
git commit -m "Add player_action kind to Event::KINDS (Phase 8.1)"
```

---

## Task 2: Add `closed_at` to scenes + `Scene#closed?`

**Files:**
- Create: `db/migrate/<ts>_add_closed_at_to_scenes.rb`
- Modify: `app/models/scene.rb`
- Modify: `spec/models/scene_spec.rb`

- [ ] **Step 2.1: Write the failing model spec**

Add to `spec/models/scene_spec.rb`:

```ruby
describe "#closed?" do
  it "is false when closed_at is nil" do
    scene = build(:scene, closed_at: nil)
    expect(scene.closed?).to be(false)
  end

  it "is true when closed_at is set" do
    scene = build(:scene, closed_at: Time.current)
    expect(scene.closed?).to be(true)
  end
end
```

- [ ] **Step 2.2: Run and confirm failure**

```
bundle exec rspec spec/models/scene_spec.rb -e "#closed?"
```

Expected: `closed_at=` undefined / `NoMethodError`.

- [ ] **Step 2.3: Generate the migration**

```
bin/rails g migration AddClosedAtToScenes closed_at:datetime
```

- [ ] **Step 2.4: Edit the migration**

Replace the generated file's body with:

```ruby
class AddClosedAtToScenes < ActiveRecord::Migration[8.1]
  def change
    add_column :scenes, :closed_at, :datetime, null: true
    add_index  :scenes, :closed_at
  end
end
```

- [ ] **Step 2.5: Run the migration in dev and test**

```
bin/rails db:migrate
RAILS_ENV=test bin/rails db:migrate
```

- [ ] **Step 2.6: Add `closed?` to the model**

Edit `app/models/scene.rb`. Inside the class body, after the `validates :title` line, add:

```ruby
def closed?
  closed_at.present?
end
```

- [ ] **Step 2.7: Refresh annotation**

```
bundle exec annotaterb models
```

- [ ] **Step 2.8: Run and confirm pass**

```
bundle exec rspec spec/models/scene_spec.rb
```

Expected: all green.

- [ ] **Step 2.9: Commit**

```
git add db/migrate/*_add_closed_at_to_scenes.rb db/schema.rb app/models/scene.rb spec/factories/scenes.rb spec/models/scene_spec.rb
git commit -m "Add closed_at to Scene + closed? helper (Phase 8.2)"
```

---

## Task 3: Create `scene_audits` table + `SceneAudit` model

**Files:**
- Create: `db/migrate/<ts>_create_scene_audits.rb`
- Create: `app/models/scene_audit.rb`
- Create: `spec/factories/scene_audits.rb`
- Create: `spec/models/scene_audit_spec.rb`
- Modify: `app/models/scene.rb` (`has_one :audit`)
- Modify: `app/models/campaign.rb` (`has_many :scene_audits, through: :scenes, source: :audit`)

- [ ] **Step 3.1: Generate the migration**

```
bin/rails g migration CreateSceneAudits
```

- [ ] **Step 3.2: Write the migration body**

Replace the file body with:

```ruby
class CreateSceneAudits < ActiveRecord::Migration[8.1]
  def change
    create_table :scene_audits do |t|
      t.references :scene,    null: false, foreign_key: { on_delete: :cascade },  index: { unique: true }
      t.references :llm_call, null: false, foreign_key: { on_delete: :restrict }
      t.string :verdict, null: false
      t.jsonb  :result,  null: false, default: {}
      t.timestamps
    end

    add_index :scene_audits, :verdict
  end
end
```

- [ ] **Step 3.3: Migrate dev + test**

```
bin/rails db:migrate
RAILS_ENV=test bin/rails db:migrate
```

- [ ] **Step 3.4: Write the model**

Create `app/models/scene_audit.rb`:

```ruby
class SceneAudit < ApplicationRecord
  belongs_to :scene
  belongs_to :llm_call

  VERDICTS = %w[pass concerns fail].freeze

  validates :verdict, presence: true, inclusion: { in: VERDICTS }
  validates :scene_id, uniqueness: true
end
```

- [ ] **Step 3.5: Write the factory**

Create `spec/factories/scene_audits.rb`:

```ruby
FactoryBot.define do
  factory :scene_audit do
    scene
    association :llm_call, factory: :llm_call
    verdict { "pass" }
    result {
      {
        "verdict" => "pass",
        "criteria" => [
          { "name" => "player_agency",            "status" => "pass", "note" => "..." },
          { "name" => "follow_through",           "status" => "pass", "note" => "..." },
          { "name" => "over_narration_of_intent", "status" => "pass", "note" => "..." },
          { "name" => "mechanical_handoff",       "status" => "pass", "note" => "..." }
        ],
        "summary" => "Looks good."
      }
    }

    trait :concerns do
      verdict { "concerns" }
      result {
        { "verdict" => "concerns",
          "criteria" => [{ "name" => "player_agency", "status" => "concerns", "note" => "..." }],
          "summary" => "Some concerns." }
      }
    end

    trait :failed do
      verdict { "fail" }
      result { { "verdict" => "fail", "summary" => "Bad." } }
    end
  end
end
```

- [ ] **Step 3.6: Write the model spec**

Create `spec/models/scene_audit_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe SceneAudit do
  describe "validations" do
    it "is valid with a verdict and a scene" do
      audit = build(:scene_audit)
      expect(audit).to be_valid
    end

    it "requires a verdict" do
      audit = build(:scene_audit, verdict: nil)
      expect(audit).not_to be_valid
    end

    it "requires verdict to be one of pass/concerns/fail" do
      audit = build(:scene_audit, verdict: "nonsense")
      expect(audit).not_to be_valid
      expect(audit.errors[:verdict]).to be_present
    end

    it "enforces one audit per scene" do
      audit = create(:scene_audit)
      duplicate = build(:scene_audit, scene: audit.scene)
      expect(duplicate).not_to be_valid
    end
  end

  describe "associations" do
    it "belongs to a scene" do
      audit = create(:scene_audit)
      expect(audit.scene).to be_a(Scene)
    end

    it "belongs to an llm_call" do
      audit = create(:scene_audit)
      expect(audit.llm_call).to be_a(LlmCall)
    end
  end

  describe "cascading delete from scene" do
    it "is removed when its scene is destroyed" do
      audit = create(:scene_audit)
      expect { audit.scene.destroy }.to change(SceneAudit, :count).by(-1)
    end
  end
end
```

- [ ] **Step 3.7: Wire scene + campaign associations**

Edit `app/models/scene.rb`. Inside the class body, after `has_many :events, ...`:

```ruby
has_one :audit, class_name: "SceneAudit", dependent: :destroy
```

Edit `app/models/campaign.rb`. After the existing `has_many :scenes, ...`:

```ruby
has_many :scene_audits, through: :scenes, source: :audit
```

- [ ] **Step 3.8: Refresh annotations**

```
bundle exec annotaterb models
```

- [ ] **Step 3.9: Run and confirm pass**

```
bundle exec rspec spec/models/scene_audit_spec.rb spec/models/scene_spec.rb spec/models/campaign_spec.rb
```

Expected: all green.

- [ ] **Step 3.10: Commit**

```
git add db/migrate/*_create_scene_audits.rb db/schema.rb app/models/scene_audit.rb app/models/scene.rb app/models/campaign.rb spec/factories/scene_audits.rb spec/models/scene_audit_spec.rb
git commit -m "Add scene_audits table + SceneAudit model + Scene/Campaign associations (Phase 8.3)"
```

---

## Task 4: Verify Campaign reaches its scene audits

**Files:**
- Modify: `spec/models/campaign_spec.rb`

- [ ] **Step 4.1: Add an integration test**

Add to `spec/models/campaign_spec.rb`:

```ruby
describe "#scene_audits" do
  it "reaches audits across scenes" do
    campaign = create(:campaign)
    scene_a  = create(:scene, campaign: campaign)
    scene_b  = create(:scene, campaign: campaign)
    audit_a  = create(:scene_audit, scene: scene_a)
    create(:scene_audit, scene: scene_b)

    expect(campaign.scene_audits).to contain_exactly(audit_a, scene_b.audit)
  end

  it "is empty for a fresh campaign with no closed scenes" do
    campaign = create(:campaign)
    expect(campaign.scene_audits).to be_empty
  end
end
```

- [ ] **Step 4.2: Run and confirm pass**

```
bundle exec rspec spec/models/campaign_spec.rb -e "#scene_audits"
```

Expected: all green (the association was added in Task 3; this just exercises it).

- [ ] **Step 4.3: Commit**

```
git add spec/models/campaign_spec.rb
git commit -m "Cover Campaign#scene_audits join (Phase 8.4)"
```

---

## Task 5: `Player::CampaignViewModel`

**Files:**
- Create: `app/view_models/player/campaign_view_model.rb`
- Create: `spec/view_models/player/campaign_view_model_spec.rb`

- [ ] **Step 5.1: Write the failing spec**

Create `spec/view_models/player/campaign_view_model_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Player::CampaignViewModel do
  let(:campaign) { create(:campaign, name: "Faerûn", description: "A high-fantasy setting.") }
  subject(:vm)   { described_class.new(campaign) }

  describe "exposed attributes" do
    it "exposes id, name, description" do
      expect(described_class.exposed_attrs).to eq(%i[id name description])
    end

    it "returns model values" do
      expect(vm.name).to eq("Faerûn")
      expect(vm.description).to eq("A high-fantasy setting.")
      expect(vm.id).to eq(campaign.id)
    end
  end

  describe "asymmetry" do
    let!(:faction) { create(:faction, :with_secrets, campaign: campaign) }
    let!(:npc)     { create(:npc, :with_secrets, campaign: campaign) }

    it "does not leak any secret content" do
      expect(vm).not_to leak_secrets_of(faction, npc)
    end
  end
end
```

(`:with_secrets` traits exist on faction/npc factories from Phase 5; if not, the trait creates one secret child via `after(:create)`. Verify with `grep -n with_secrets spec/factories/factions.rb spec/factories/npcs.rb`. If absent, add them in this task before moving on.)

- [ ] **Step 5.2: Add `:with_secrets` traits if missing**

Check:

```
grep -n with_secrets spec/factories/factions.rb spec/factories/npcs.rb
```

If absent, add to `spec/factories/factions.rb`:

```ruby
trait :with_secrets do
  after(:create) do |faction|
    create(:faction_secret, faction: faction, label: "hidden temple", content: "is buried in the swamp")
    create(:faction_secret, faction: faction, label: "true founder", content: "was once a paladin of Tyr")
  end
end
```

And to `spec/factories/npcs.rb`:

```ruby
trait :with_secrets do
  after(:create) do |npc|
    create(:npc_secret, npc: npc, label: "true identity",  content: "is actually a doppelganger")
    create(:npc_secret, npc: npc, label: "hidden patron",  content: "secretly serves House Vol")
  end
end
```

- [ ] **Step 5.3: Run and confirm failure**

```
bundle exec rspec spec/view_models/player/campaign_view_model_spec.rb
```

Expected: `Player::CampaignViewModel` is not defined.

- [ ] **Step 5.4: Implement the VM**

Create `app/view_models/player/campaign_view_model.rb`:

```ruby
module Player
  class CampaignViewModel < ApplicationViewModel
    expose :id, :name, :description
  end
end
```

- [ ] **Step 5.5: Run and confirm pass**

```
bundle exec rspec spec/view_models/player/campaign_view_model_spec.rb
```

Expected: all green.

- [ ] **Step 5.6: Commit**

```
git add app/view_models/player/campaign_view_model.rb spec/view_models/player/campaign_view_model_spec.rb spec/factories/factions.rb spec/factories/npcs.rb
git commit -m "Add Player::CampaignViewModel (Phase 8.5)"
```

---

## Task 6: `Player::EventViewModel`

**Files:**
- Create: `app/view_models/player/event_view_model.rb`
- Create: `spec/view_models/player/event_view_model_spec.rb`

- [ ] **Step 6.1: Write the failing spec**

Create `spec/view_models/player/event_view_model_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Player::EventViewModel do
  let(:scene) { create(:scene) }

  describe "exposed attributes" do
    it "exposes id, kind, occurred_at, text, occurred_at_label" do
      expect(described_class.exposed_attrs).to eq(%i[id kind occurred_at text occurred_at_label])
    end
  end

  describe "#text by kind" do
    it "renders narration text" do
      event = create(:event, scene: scene, kind: "narration",
                     payload: { "text" => "The door swings open." })
      expect(described_class.new(event).text).to eq("The door swings open.")
    end

    it "renders player_action text" do
      event = create(:event, scene: scene, kind: "player_action",
                     payload: { "text" => "I open the door." })
      expect(described_class.new(event).text).to eq("I open the door.")
    end

    it "renders dice_roll as expression and result" do
      event = create(:event, scene: scene, kind: "dice_roll",
                     payload: { "expression" => "2d6+3", "result" => 11 })
      expect(described_class.new(event).text).to eq("Rolled 2d6+3 → 11")
    end

    it "renders oracle_query with question, likelihood, chaos, answer" do
      event = create(:event, scene: scene, kind: "oracle_query",
                     payload: { "question" => "Does the door open?",
                                "likelihood" => "50_50", "chaos" => 5, "answer" => "Yes" })
      vm = described_class.new(event)
      expect(vm.text).to eq("Asked: Does the door open? (50_50, chaos 5) → Yes")
    end

    it "renders scene_transition with reason" do
      event = create(:event, scene: scene, kind: "scene_transition",
                     payload: { "reason" => "Travel to the next town." })
      expect(described_class.new(event).text).to eq("Travel to the next town.")
    end
  end

  describe "#occurred_at_label" do
    it "is the iso8601 timestamp" do
      time = Time.zone.parse("2026-05-14T20:00:00Z")
      event = create(:event, scene: scene, kind: "narration", payload: { "text" => "x" }, occurred_at: time)
      expect(described_class.new(event).occurred_at_label).to eq(time.iso8601)
    end
  end

  describe "asymmetry" do
    let!(:faction) { create(:faction, :with_secrets, campaign: scene.campaign) }
    let!(:npc)     { create(:npc, :with_secrets, campaign: scene.campaign) }
    let(:event)    { create(:event, scene: scene, kind: "narration", payload: { "text" => "Nothing hidden here." }) }

    it "does not leak secrets" do
      vm = described_class.new(event)
      expect(vm).not_to leak_secrets_of(faction, npc)
    end
  end
end
```

- [ ] **Step 6.2: Run and confirm failure**

```
bundle exec rspec spec/view_models/player/event_view_model_spec.rb
```

Expected: `Player::EventViewModel` undefined.

- [ ] **Step 6.3: Implement the VM**

Create `app/view_models/player/event_view_model.rb`:

```ruby
module Player
  class EventViewModel < ApplicationViewModel
    expose :id, :kind, :occurred_at

    expose :text do
      render_text
    end

    expose :occurred_at_label do
      @record.occurred_at.iso8601
    end

    private

    def render_text
      case @record.kind
      when "narration"        then @record.payload["text"].to_s
      when "player_action"    then @record.payload["text"].to_s
      when "dice_roll"        then "Rolled #{@record.payload["expression"]} → #{@record.payload["result"]}"
      when "oracle_query"     then "Asked: #{@record.payload["question"]} (#{@record.payload["likelihood"]}, chaos #{@record.payload["chaos"]}) → #{@record.payload["answer"]}"
      when "scene_transition" then @record.payload["reason"].to_s
      else                         ""
      end
    end
  end
end
```

- [ ] **Step 6.4: Run and confirm pass**

```
bundle exec rspec spec/view_models/player/event_view_model_spec.rb
```

Expected: all green.

- [ ] **Step 6.5: Commit**

```
git add app/view_models/player/event_view_model.rb spec/view_models/player/event_view_model_spec.rb
git commit -m "Add Player::EventViewModel (Phase 8.6)"
```

---

## Task 7: `Player::SceneViewModel`

**Files:**
- Create: `app/view_models/player/scene_view_model.rb`
- Create: `spec/view_models/player/scene_view_model_spec.rb`

- [ ] **Step 7.1: Write the failing spec**

Create `spec/view_models/player/scene_view_model_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Player::SceneViewModel do
  let(:scene) { create(:scene, title: "The Tavern", summary: "A noisy hall.") }
  subject(:vm) { described_class.new(scene) }

  describe "exposed attributes" do
    it "exposes id, title, summary, events" do
      expect(described_class.exposed_attrs).to eq(%i[id title summary events])
    end

    it "returns title and summary" do
      expect(vm.title).to eq("The Tavern")
      expect(vm.summary).to eq("A noisy hall.")
    end
  end

  describe "#events" do
    it "wraps events in Player::EventViewModel ordered by occurred_at" do
      older  = create(:event, scene: scene, kind: "narration", payload: { "text" => "first" }, occurred_at: 2.minutes.ago)
      newer  = create(:event, scene: scene, kind: "narration", payload: { "text" => "second" }, occurred_at: 1.minute.ago)

      events = vm.events
      expect(events.length).to eq(2)
      expect(events).to all(be_a(Player::EventViewModel))
      expect(events.first.id).to eq(older.id)
      expect(events.last.id).to eq(newer.id)
    end

    it "returns an empty array on a fresh scene" do
      expect(vm.events).to eq([])
    end
  end

  describe "asymmetry" do
    let!(:faction) { create(:faction, :with_secrets, campaign: scene.campaign) }
    let!(:npc)     { create(:npc, :with_secrets, campaign: scene.campaign) }

    before do
      create(:event, scene: scene, kind: "narration", payload: { "text" => "Nothing hidden here." })
    end

    it "does not leak secrets via events" do
      expect(vm).not_to leak_secrets_of(faction, npc)
    end

    it "does not expose campaign or factions/npcs as attrs" do
      expect(described_class.exposed_attrs).not_to include(:campaign, :factions, :npcs)
    end
  end
end
```

- [ ] **Step 7.2: Run and confirm failure**

```
bundle exec rspec spec/view_models/player/scene_view_model_spec.rb
```

Expected: undefined constant.

- [ ] **Step 7.3: Implement the VM**

Create `app/view_models/player/scene_view_model.rb`:

```ruby
module Player
  class SceneViewModel < ApplicationViewModel
    expose :id, :title, :summary

    expose :events do
      @record.events.order(:occurred_at).map { Player::EventViewModel.new(_1) }
    end
  end
end
```

- [ ] **Step 7.4: Run and confirm pass**

```
bundle exec rspec spec/view_models/player/scene_view_model_spec.rb
```

Expected: all green.

- [ ] **Step 7.5: Commit**

```
git add app/view_models/player/scene_view_model.rb spec/view_models/player/scene_view_model_spec.rb
git commit -m "Add Player::SceneViewModel (Phase 8.7)"
```

---

## Task 8: Narrator-side audit ViewModels

**Files:**
- Create: `app/view_models/narrator/event_view_model.rb`
- Create: `app/view_models/narrator/scene_audit_view_model.rb`
- Create: `spec/view_models/narrator/event_view_model_spec.rb`
- Create: `spec/view_models/narrator/scene_audit_view_model_spec.rb`

- [ ] **Step 8.1: Write the failing event spec**

Create `spec/view_models/narrator/event_view_model_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Narrator::EventViewModel do
  let(:scene) { create(:scene) }
  let(:event) { create(:event, scene: scene, kind: "narration", payload: { "text" => "ok" }) }

  it "exposes id, kind, occurred_at, text, occurred_at_label" do
    expect(described_class.exposed_attrs).to eq(%i[id kind occurred_at text occurred_at_label])
  end

  it "renders text per kind same as Player::EventViewModel" do
    expect(described_class.new(event).text).to eq("ok")
  end
end
```

- [ ] **Step 8.2: Implement the event VM**

Create `app/view_models/narrator/event_view_model.rb`:

```ruby
module Narrator
  class EventViewModel < ApplicationViewModel
    expose :id, :kind, :occurred_at

    expose :text do
      render_text
    end

    expose :occurred_at_label do
      @record.occurred_at.iso8601
    end

    private

    def render_text
      case @record.kind
      when "narration"        then @record.payload["text"].to_s
      when "player_action"    then @record.payload["text"].to_s
      when "dice_roll"        then "Rolled #{@record.payload["expression"]} → #{@record.payload["result"]}"
      when "oracle_query"     then "Asked: #{@record.payload["question"]} (#{@record.payload["likelihood"]}, chaos #{@record.payload["chaos"]}) → #{@record.payload["answer"]}"
      when "scene_transition" then @record.payload["reason"].to_s
      else                         ""
      end
    end
  end
end
```

(For Phase 8 the narrator-side renders the same content as the Player-side. The class exists separately so future phases can add narrator-only event fields.)

- [ ] **Step 8.3: Write the failing scene_audit spec**

Create `spec/view_models/narrator/scene_audit_view_model_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Narrator::SceneAuditViewModel do
  let(:scene) { create(:scene, title: "T", summary: "S") }
  subject(:vm) { described_class.new(scene) }

  it "exposes id, title, summary, events" do
    expect(described_class.exposed_attrs).to eq(%i[id title summary events])
  end

  it "wraps events in Narrator::EventViewModel" do
    create(:event, scene: scene, kind: "narration", payload: { "text" => "x" })
    expect(vm.events).to all(be_a(Narrator::EventViewModel))
  end
end
```

- [ ] **Step 8.4: Implement the scene_audit VM**

Create `app/view_models/narrator/scene_audit_view_model.rb`:

```ruby
module Narrator
  class SceneAuditViewModel < ApplicationViewModel
    expose :id, :title, :summary

    expose :events do
      @record.events.order(:occurred_at).map { Narrator::EventViewModel.new(_1) }
    end
  end
end
```

- [ ] **Step 8.5: Run and confirm pass**

```
bundle exec rspec spec/view_models/narrator/event_view_model_spec.rb spec/view_models/narrator/scene_audit_view_model_spec.rb
```

- [ ] **Step 8.6: Commit**

```
git add app/view_models/narrator/event_view_model.rb app/view_models/narrator/scene_audit_view_model.rb spec/view_models/narrator/event_view_model_spec.rb spec/view_models/narrator/scene_audit_view_model_spec.rb
git commit -m "Add Narrator::EventViewModel + Narrator::SceneAuditViewModel (Phase 8.8)"
```

---

## Task 9: Refactor `Llm::Providers::Anthropic#call` to extract request body building

This is a behavior-preserving refactor. Existing Phase 4 tests must stay green; no new behavior yet.

**Files:**
- Modify: `app/lib/llm/providers/anthropic.rb`

- [ ] **Step 9.1: Run the existing adapter spec to confirm baseline green**

```
bundle exec rspec spec/lib/llm/providers/anthropic_spec.rb
```

Expected: all green. (If not, fix before proceeding.)

- [ ] **Step 9.2: Extract `build_request_body` and `normalize_system`**

Edit `app/lib/llm/providers/anthropic.rb`. Replace the `def call` method's request_body construction with a call to a new private helper. The full file becomes:

```ruby
require_relative "../error"
require_relative "../result"

module Llm
  module Providers
    class Anthropic
      attr_reader :model

      def initialize(model:)
        @model = model
      end

      # Returns Llm::Result. Never raises on HTTP/transport errors —
      # those are captured into result.error. Raises Llm::ConfigError
      # if the API key is missing from Rails credentials.
      def call(system: nil, messages:, max_tokens: 1024, cache_breakpoints: [])
        api_key = self.class.api_key
        raise Llm::ConfigError, "Anthropic API key not configured (credentials.anthropic.api_key)" if api_key.blank?

        request_body = build_request_body(system: system, messages: messages,
                                          max_tokens: max_tokens, cache_breakpoints: cache_breakpoints)

        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        begin
          response = self.class.sdk_client.messages.create(**request_body)
          latency_ms = elapsed_ms(started_at)

          Llm::Result.new(
            text:                  response.content.first.text,
            input_tokens:          response.usage.input_tokens.to_i,
            output_tokens:         response.usage.output_tokens.to_i,
            cache_creation_tokens: cache_creation_from(response.usage),
            cache_read_tokens:     cache_read_from(response.usage),
            provider_request_id:   response.id,
            prompt_payload:        request_body.deep_stringify_keys,
            response_payload:      JSON.parse(response.to_json),
            latency_ms:            latency_ms,
            error:                 nil
          )
        rescue ::Anthropic::Errors::Error => e
          latency_ms = elapsed_ms(started_at)
          Llm::Result.new(
            text: nil,
            input_tokens: 0, output_tokens: 0,
            cache_creation_tokens: 0, cache_read_tokens: 0,
            provider_request_id: nil,
            prompt_payload: request_body.deep_stringify_keys,
            response_payload: { "error" => { "class" => e.class.name, "message" => e.message } },
            latency_ms: latency_ms,
            error: Llm::ProviderError.new(
              provider_class:   e.class.name,
              provider_message: e.message
            )
          )
        end
      end

      def self.sdk_client
        @sdk_client ||= ::Anthropic::Client.new(api_key: api_key)
      end

      def self.api_key
        Rails.application.credentials.dig(:anthropic, :api_key)
      end

      def self.reset_client!
        @sdk_client = nil
      end

      private

      def build_request_body(system:, messages:, max_tokens:, cache_breakpoints:)
        body = {
          model: model,
          max_tokens: max_tokens,
          messages: messages
        }
        if system
          body[:system] = normalize_system(system, cache_breakpoints)
        elsif cache_breakpoints.any?
          raise Llm::ConfigError, "cache_breakpoints requires a non-nil system parameter"
        end
        body
      end

      def normalize_system(system, cache_breakpoints)
        blocks = case system
                 when String then [{ type: "text", text: system }]
                 when Array  then system.map(&:dup)
                 else             raise Llm::ConfigError, "system must be a String or Array of typed blocks"
                 end
        cache_breakpoints.each do |bp|
          index, ttl = case bp
                       when Integer then [bp, :ephemeral_5m]
                       when Hash    then [bp.fetch(:index), bp.fetch(:ttl, :ephemeral_5m)]
                       end
          blocks[index][:cache_control] = { type: "ephemeral", ttl: ttl_to_anthropic(ttl) }
        end
        blocks
      end

      def ttl_to_anthropic(ttl)
        case ttl
        when :ephemeral_5m then "5m"
        when :ephemeral_1h then "1h"
        else raise Llm::ConfigError, "Unknown cache TTL: #{ttl.inspect}"
        end
      end

      def elapsed_ms(started_at)
        ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
      end

      def cache_creation_from(usage)
        return 0 unless usage.respond_to?(:cache_creation_input_tokens)
        value = usage.cache_creation_input_tokens
        value.nil? ? 0 : value.to_i
      end

      def cache_read_from(usage)
        return 0 unless usage.respond_to?(:cache_read_input_tokens)
        value = usage.cache_read_input_tokens
        value.nil? ? 0 : value.to_i
      end
    end
  end
end
```

Key changes vs the existing file:
- `call` grows a `cache_breakpoints: []` keyword.
- Request body construction is in `build_request_body`.
- `normalize_system` wraps a String into a 1-block Array (Phase 4 backward compat) and decorates the indexed blocks with `cache_control`.
- `ttl_to_anthropic` maps internal symbols to the SDK's TTL strings.

- [ ] **Step 9.3: Run the existing adapter spec — must stay green**

```
bundle exec rspec spec/lib/llm/providers/anthropic_spec.rb
```

Expected: all green. The `cache_breakpoints` default of `[]` keeps Phase 4 behavior identical.

- [ ] **Step 9.4: Commit the refactor**

```
git add app/lib/llm/providers/anthropic.rb
git commit -m "Refactor Anthropic adapter: extract build_request_body + normalize_system (Phase 8.9)"
```

---

## Task 10: Test cache_breakpoints on `Llm::Providers::Anthropic#call`

**Files:**
- Modify: `spec/lib/llm/providers/anthropic_spec.rb`

- [ ] **Step 10.1: Write the cache_breakpoints test**

Add to `spec/lib/llm/providers/anthropic_spec.rb` (inside the existing top-level `describe`):

```ruby
describe "cache_breakpoints" do
  let(:adapter) { described_class.new(model: "claude-sonnet-4-6") }

  before { stub_anthropic_messages_create(text: "hi", input_tokens: 1, output_tokens: 1) }

  it "decorates the indicated system block with ephemeral 5m cache_control" do
    adapter.call(
      system: [{ type: "text", text: "rules" }, { type: "text", text: "roster" }],
      messages: [{ role: "user", content: "hi" }],
      cache_breakpoints: [0]
    )

    expect(WebMock).to have_requested(:post, "https://api.anthropic.com/v1/messages")
      .with { |req|
        body = JSON.parse(req.body)
        body["system"][0]["cache_control"] == { "type" => "ephemeral", "ttl" => "5m" } &&
          !body["system"][1].key?("cache_control")
      }
  end

  it "supports per-breakpoint TTL via Hash form" do
    adapter.call(
      system: [{ type: "text", text: "rules" }, { type: "text", text: "roster" }],
      messages: [{ role: "user", content: "hi" }],
      cache_breakpoints: [{ index: 1, ttl: :ephemeral_1h }]
    )

    expect(WebMock).to have_requested(:post, "https://api.anthropic.com/v1/messages")
      .with { |req|
        body = JSON.parse(req.body)
        body["system"][1]["cache_control"] == { "type" => "ephemeral", "ttl" => "1h" }
      }
  end

  it "wraps a String system into a single typed block when cache_breakpoints empty" do
    adapter.call(system: "just a string", messages: [{ role: "user", content: "hi" }])

    expect(WebMock).to have_requested(:post, "https://api.anthropic.com/v1/messages")
      .with { |req|
        body = JSON.parse(req.body)
        body["system"] == [{ "type" => "text", "text" => "just a string" }]
      }
  end

  it "raises ConfigError when cache_breakpoints is set without a system" do
    expect {
      adapter.call(messages: [{ role: "user", content: "hi" }], cache_breakpoints: [0])
    }.to raise_error(Llm::ConfigError, /cache_breakpoints requires/)
  end
end
```

The `stub_anthropic_messages_create` helper exists in Phase 4's spec support; if not, find and reuse the equivalent stub idiom from `spec/lib/llm/providers/anthropic_spec.rb`'s existing tests.

- [ ] **Step 10.2: Run and confirm pass**

```
bundle exec rspec spec/lib/llm/providers/anthropic_spec.rb -e "cache_breakpoints"
```

Expected: 4 examples passing.

- [ ] **Step 10.3: Commit**

```
git add spec/lib/llm/providers/anthropic_spec.rb
git commit -m "Test cache_breakpoints on Llm::Providers::Anthropic#call (Phase 8.10)"
```

---

## Task 11: Add `#call_streaming` to `Llm::Providers::Anthropic`

**Files:**
- Modify: `app/lib/llm/providers/anthropic.rb`
- Create: `spec/support/anthropic_streaming.rb`
- Create: `spec/lib/llm/providers/anthropic_streaming_spec.rb`

- [ ] **Step 11.1: Write the streaming WebMock helper**

Create `spec/support/anthropic_streaming.rb`:

```ruby
# Helpers for stubbing Anthropic Messages streaming responses (server-sent events).
#
# Usage:
#   stub_anthropic_streaming(text_chunks: ["Hello ", "world."],
#                            input_tokens: 12, output_tokens: 7)
module AnthropicStreamingHelpers
  def stub_anthropic_streaming(text_chunks:, input_tokens: 10, output_tokens: 5,
                               cache_creation_tokens: 0, cache_read_tokens: 0,
                               message_id: "msg_test_#{SecureRandom.hex(4)}")
    body = build_sse_body(
      text_chunks: text_chunks,
      message_id: message_id,
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      cache_creation_tokens: cache_creation_tokens,
      cache_read_tokens: cache_read_tokens
    )

    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(
        status: 200,
        headers: { "Content-Type" => "text/event-stream" },
        body: body
      )
  end

  def stub_anthropic_streaming_error(status:, error_class: "Anthropic::Errors::APIStatusError",
                                     message: "stub error")
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(
        status: status,
        headers: { "Content-Type" => "application/json" },
        body: { "error" => { "type" => "api_error", "message" => message } }.to_json
      )
  end

  private

  def build_sse_body(text_chunks:, message_id:, input_tokens:, output_tokens:,
                     cache_creation_tokens:, cache_read_tokens:)
    events = []
    events << sse_event("message_start", {
      type: "message_start",
      message: {
        id: message_id, type: "message", role: "assistant", model: "claude-sonnet-4-6",
        content: [], stop_reason: nil, stop_sequence: nil,
        usage: {
          input_tokens: input_tokens, output_tokens: 0,
          cache_creation_input_tokens: cache_creation_tokens,
          cache_read_input_tokens: cache_read_tokens
        }
      }
    })
    events << sse_event("content_block_start", {
      type: "content_block_start", index: 0,
      content_block: { type: "text", text: "" }
    })
    text_chunks.each do |chunk|
      events << sse_event("content_block_delta", {
        type: "content_block_delta", index: 0,
        delta: { type: "text_delta", text: chunk }
      })
    end
    events << sse_event("content_block_stop", { type: "content_block_stop", index: 0 })
    events << sse_event("message_delta", {
      type: "message_delta",
      delta: { stop_reason: "end_turn", stop_sequence: nil },
      usage: { output_tokens: output_tokens }
    })
    events << sse_event("message_stop", { type: "message_stop" })
    events.join
  end

  def sse_event(name, data)
    "event: #{name}\ndata: #{data.to_json}\n\n"
  end
end

RSpec.configure do |c|
  c.include AnthropicStreamingHelpers
end
```

(SSE encoding follows the format Anthropic's streaming endpoint emits — `event:` line, `data:` line, blank line. The SDK reads this through `Anthropic::Internal::Stream`.)

- [ ] **Step 11.2: Add `#call_streaming` to the adapter**

Edit `app/lib/llm/providers/anthropic.rb`. Inside the class, after the `def call ... end` method, add:

```ruby
# Streaming variant. Yields each text delta to &on_chunk as { text: String }.
# Returns Llm::Result at completion (text accumulates the full response).
# On error, returns an Llm::Result with `error` populated and any partial text
# captured into prompt_payload["partial_text"].
def call_streaming(system: nil, messages:, max_tokens: 4096,
                   cache_breakpoints: [], &on_chunk)
  api_key = self.class.api_key
  raise Llm::ConfigError, "Anthropic API key not configured (credentials.anthropic.api_key)" if api_key.blank?

  request_body = build_request_body(system: system, messages: messages,
                                    max_tokens: max_tokens, cache_breakpoints: cache_breakpoints)

  started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  text       = +""

  begin
    stream = self.class.sdk_client.messages.stream(**request_body)
    stream.text.each do |delta|
      text << delta
      on_chunk&.call(text: delta)
    end
    message = stream.accumulated_message
    latency_ms = elapsed_ms(started_at)

    Llm::Result.new(
      text:                  text,
      input_tokens:          message.usage.input_tokens.to_i,
      output_tokens:         message.usage.output_tokens.to_i,
      cache_creation_tokens: cache_creation_from(message.usage),
      cache_read_tokens:     cache_read_from(message.usage),
      provider_request_id:   message.id,
      prompt_payload:        request_body.deep_stringify_keys,
      response_payload:      JSON.parse(message.to_json),
      latency_ms:            latency_ms,
      error:                 nil
    )
  rescue ::Anthropic::Errors::Error => e
    latency_ms = elapsed_ms(started_at)
    Llm::Result.new(
      text: text.presence,
      input_tokens: 0, output_tokens: 0,
      cache_creation_tokens: 0, cache_read_tokens: 0,
      provider_request_id: nil,
      prompt_payload: request_body.deep_stringify_keys.merge("partial_text" => text),
      response_payload: { "error" => { "class" => e.class.name, "message" => e.message } },
      latency_ms: latency_ms,
      error: Llm::ProviderError.new(provider_class: e.class.name, provider_message: e.message)
    )
  end
end
```

- [ ] **Step 11.3: Write the streaming spec**

Create `spec/lib/llm/providers/anthropic_streaming_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Llm::Providers::Anthropic, "#call_streaming" do
  let(:adapter) { described_class.new(model: "claude-sonnet-4-6") }
  let(:messages) { [{ role: "user", content: "Hi." }] }

  before do
    allow(Rails.application.credentials).to receive(:dig).with(:anthropic, :api_key).and_return("sk-test")
    described_class.reset_client!
  end

  describe "happy path" do
    before do
      stub_anthropic_streaming(
        text_chunks: ["Hello ", "world", "."],
        input_tokens: 12, output_tokens: 7,
        cache_creation_tokens: 100, cache_read_tokens: 200
      )
    end

    it "yields each delta in order" do
      received = []
      adapter.call_streaming(messages: messages) { |text:| received << text }
      expect(received).to eq(["Hello ", "world", "."])
    end

    it "returns an Llm::Result with concatenated text and tokens" do
      result = adapter.call_streaming(messages: messages)
      expect(result.successful?).to be(true)
      expect(result.text).to eq("Hello world.")
      expect(result.input_tokens).to eq(12)
      expect(result.output_tokens).to eq(7)
      expect(result.cache_creation_tokens).to eq(100)
      expect(result.cache_read_tokens).to eq(200)
      expect(result.provider_request_id).to start_with("msg_test_")
    end

    it "captures latency_ms" do
      result = adapter.call_streaming(messages: messages)
      expect(result.latency_ms).to be >= 0
    end
  end

  describe "cache_breakpoints" do
    before { stub_anthropic_streaming(text_chunks: ["x"]) }

    it "decorates the indicated system block" do
      adapter.call_streaming(
        system: [{ type: "text", text: "rules" }, { type: "text", text: "roster" }],
        messages: messages,
        cache_breakpoints: [0]
      )

      expect(WebMock).to have_requested(:post, "https://api.anthropic.com/v1/messages")
        .with { |req|
          body = JSON.parse(req.body)
          body["system"][0]["cache_control"] == { "type" => "ephemeral", "ttl" => "5m" }
        }
    end
  end

  describe "error path" do
    before { stub_anthropic_streaming_error(status: 500, message: "boom") }

    it "returns an errored result" do
      result = adapter.call_streaming(messages: messages)
      expect(result.successful?).to be(false)
      expect(result.response_payload).to have_key("error")
      expect(result.error).to be_a(Llm::ProviderError)
    end
  end

  describe "missing API key" do
    before do
      allow(Rails.application.credentials).to receive(:dig).with(:anthropic, :api_key).and_return(nil)
      described_class.reset_client!
    end

    it "raises Llm::ConfigError" do
      expect {
        adapter.call_streaming(messages: messages)
      }.to raise_error(Llm::ConfigError, /API key/)
    end
  end
end
```

- [ ] **Step 11.4: Run and confirm pass**

```
bundle exec rspec spec/lib/llm/providers/anthropic_streaming_spec.rb
```

Expected: all green. If the SDK rejects the SSE body shape, adjust `build_sse_body` to match what `Anthropic::Internal::Stream` parses (verify by reading the `Anthropic::Internal::Stream` class in the gem source if the test fails).

- [ ] **Step 11.5: Commit**

```
git add spec/support/anthropic_streaming.rb app/lib/llm/providers/anthropic.rb spec/lib/llm/providers/anthropic_streaming_spec.rb
git commit -m "Add Llm::Providers::Anthropic#call_streaming + SSE test helper (Phase 8.11)"
```

---

## Task 12: Refactor `Llm::Call.execute` to extract `compute_cost_cents` + add cache kwargs

**Files:**
- Modify: `app/lib/llm/call.rb`

- [ ] **Step 12.1: Run the existing call spec to confirm baseline green**

```
bundle exec rspec spec/lib/llm/call_spec.rb
```

Expected: all green.

- [ ] **Step 12.2: Refactor**

Replace `app/lib/llm/call.rb` body with:

```ruby
require_relative "error"

module Llm
  module Call
    # Returns the persisted LlmCall record. Raises Llm::ConfigError on
    # missing API key or unknown purpose / model override. Never raises
    # on HTTP errors — those are persisted into the row's response_payload.
    def self.execute(purpose:, messages:, system: nil, max_tokens: 1024,
                     cache_breakpoints: [], cache_ttl: :ephemeral_5m,
                     user:, campaign: nil, scene: nil, model: nil)
      adapter = Llm::Provider.for(purpose)
      adapter = override_model(adapter, model) if model

      result = adapter.call(
        system: system, messages: messages, max_tokens: max_tokens,
        cache_breakpoints: cache_breakpoints
      )

      persist!(adapter: adapter, purpose: purpose, result: result, cache_ttl: cache_ttl,
               user: user, campaign: campaign, scene: scene)
    end

    # Streaming variant. Yields each text delta to &on_chunk as { text: String }.
    # Returns the persisted LlmCall record.
    def self.execute_streaming(purpose:, messages:, system: nil, max_tokens: 4096,
                               cache_breakpoints: [], cache_ttl: :ephemeral_5m,
                               user:, campaign: nil, scene: nil, model: nil,
                               &on_chunk)
      adapter = Llm::Provider.for(purpose)
      adapter = override_model(adapter, model) if model

      result = adapter.call_streaming(
        system: system, messages: messages, max_tokens: max_tokens,
        cache_breakpoints: cache_breakpoints, &on_chunk
      )

      persist!(adapter: adapter, purpose: purpose, result: result, cache_ttl: cache_ttl,
               user: user, campaign: campaign, scene: scene)
    end

    def self.override_model(adapter, model)
      raise Llm::ConfigError, "Unknown model: #{model}" unless Llm::Pricing.known_models.include?(model)
      adapter.class.new(model: model)
    end

    def self.provider_name_for(purpose)
      Llm::Provider::PURPOSES.fetch(purpose)[:provider].to_s
    end

    def self.persist!(adapter:, purpose:, result:, cache_ttl:, user:, campaign:, scene:)
      cost_cents = compute_cost_cents(result, adapter.model, cache_ttl)

      LlmCall.create!(
        user:                  user,
        campaign:              campaign,
        scene_id:              scene&.id,
        purpose:               purpose.to_s,
        provider:              provider_name_for(purpose),
        model:                 adapter.model,
        input_tokens:          result.input_tokens,
        output_tokens:         result.output_tokens,
        cache_creation_tokens: result.cache_creation_tokens,
        cache_read_tokens:     result.cache_read_tokens,
        total_cost_cents:      cost_cents,
        latency_ms:            result.latency_ms,
        provider_request_id:   result.provider_request_id,
        prompt_payload:        result.prompt_payload,
        response_payload:      result.response_payload
      )
    end

    def self.compute_cost_cents(result, model, cache_ttl)
      return 0 unless result.successful?

      Llm::Pricing.cost_cents(
        usage: {
          input:          result.input_tokens,
          output:         result.output_tokens,
          cache_creation: result.cache_creation_tokens,
          cache_read:     result.cache_read_tokens
        },
        model: model,
        cache_ttl: cache_ttl
      )
    end
  end
end
```

- [ ] **Step 12.3: Re-run the existing call spec**

```
bundle exec rspec spec/lib/llm/call_spec.rb
```

Expected: all green (the refactor is invisible to existing callers; new keywords default to no-op values).

- [ ] **Step 12.4: Add a streaming-execute spec**

Add to `spec/lib/llm/call_spec.rb` inside the existing top-level describe:

```ruby
describe ".execute_streaming" do
  let(:user) { create(:user) }

  before do
    allow(Rails.application.credentials).to receive(:dig).with(:anthropic, :api_key).and_return("sk-test")
    Llm::Providers::Anthropic.reset_client!
  end

  it "writes an LlmCall row with streamed content" do
    stub_anthropic_streaming(text_chunks: ["Hi ", "there."], input_tokens: 5, output_tokens: 3)

    received = []
    call = Llm::Call.execute_streaming(
      purpose: :narration,
      messages: [{ role: "user", content: "x" }],
      user: user
    ) { |text:| received << text }

    expect(received).to eq(["Hi ", "there."])
    expect(call).to be_persisted
    expect(call.purpose).to eq("narration")
    expect(call.text).to eq("Hi there.")
    expect(call.input_tokens).to eq(5)
    expect(call.output_tokens).to eq(3)
    expect(call.successful?).to be(true)
  end

  it "writes a row with error info when the stream fails" do
    stub_anthropic_streaming_error(status: 500, message: "boom")

    call = Llm::Call.execute_streaming(
      purpose: :narration,
      messages: [{ role: "user", content: "x" }],
      user: user
    )

    expect(call.successful?).to be(false)
    expect(call.error_message).to include("boom")
  end
end
```

- [ ] **Step 12.5: Run and confirm pass**

```
bundle exec rspec spec/lib/llm/call_spec.rb
```

Expected: all green.

- [ ] **Step 12.6: Commit**

```
git add app/lib/llm/call.rb spec/lib/llm/call_spec.rb
git commit -m "Refactor Llm::Call: extract compute_cost_cents + add execute_streaming (Phase 8.12)"
```

---

## Task 13: Register `:bookkeeper_audit` purpose

**Files:**
- Modify: `app/lib/llm/provider.rb`
- Modify: `spec/lib/llm/provider_spec.rb`

- [ ] **Step 13.1: Write the failing test**

Add to `spec/lib/llm/provider_spec.rb`:

```ruby
describe "for(:bookkeeper_audit)" do
  it "returns an Anthropic adapter on Sonnet 4.6" do
    adapter = Llm::Provider.for(:bookkeeper_audit)
    expect(adapter).to be_a(Llm::Providers::Anthropic)
    expect(adapter.model).to eq("claude-sonnet-4-6")
  end
end
```

- [ ] **Step 13.2: Run and confirm failure**

```
bundle exec rspec spec/lib/llm/provider_spec.rb -e "bookkeeper_audit"
```

Expected: `Llm::ConfigError`: unknown purpose.

- [ ] **Step 13.3: Add the purpose**

Edit `app/lib/llm/provider.rb`. In the `PURPOSES` constant, add a line:

```ruby
PURPOSES = {
  diagnostics:         { provider: :anthropic, model: "claude-sonnet-4-6" },
  narration:           { provider: :anthropic, model: "claude-sonnet-4-6" },
  bookkeeper_audit:    { provider: :anthropic, model: "claude-sonnet-4-6" },
  intake_long_context: { provider: :anthropic, model: "claude-sonnet-4-6" }
}.freeze
```

- [ ] **Step 13.4: Run and confirm pass**

```
bundle exec rspec spec/lib/llm/provider_spec.rb
```

- [ ] **Step 13.5: Commit**

```
git add app/lib/llm/provider.rb spec/lib/llm/provider_spec.rb
git commit -m "Register :bookkeeper_audit purpose (Phase 8.13)"
```

---

## Task 14: `Narrator::Prompt` + `Narrator::SystemPrompt`

**Files:**
- Create: `app/lib/narrator/prompt.rb`
- Create: `app/lib/narrator/system_prompt.rb`
- Create: `spec/lib/narrator/prompt_spec.rb`
- Create: `spec/lib/narrator/system_prompt_spec.rb`

- [ ] **Step 14.1: Write the prompt spec**

Create `spec/lib/narrator/prompt_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Narrator::Prompt do
  let(:prompt) {
    described_class.new(
      system: [{ type: "text", text: "rules" }, { type: "text", text: "roster" }],
      messages: [{ role: "user", content: "hi" }],
      cache_breakpoints: [0, 1]
    )
  }

  it "exposes system, messages, cache_breakpoints" do
    expect(prompt.system.length).to eq(2)
    expect(prompt.messages.length).to eq(1)
    expect(prompt.cache_breakpoints).to eq([0, 1])
  end

  it "renders to a string by joining all blocks" do
    str = prompt.to_s
    expect(str).to include("rules")
    expect(str).to include("roster")
    expect(str).to include("hi")
  end

  it "produces call_kwargs with the three components" do
    kwargs = prompt.to_call_kwargs
    expect(kwargs.keys).to contain_exactly(:system, :messages, :cache_breakpoints)
  end
end
```

- [ ] **Step 14.2: Implement `Narrator::Prompt`**

Create `app/lib/narrator/prompt.rb`:

```ruby
module Narrator
  Prompt = Data.define(:system, :messages, :cache_breakpoints) do
    def to_call_kwargs
      { system: system, messages: messages, cache_breakpoints: cache_breakpoints }
    end

    def to_s
      [system_text, messages_text].reject(&:empty?).join("\n\n")
    end

    private

    def system_text
      Array(system).map { _1.is_a?(Hash) ? _1[:text].to_s : _1.to_s }.join("\n\n---\n\n")
    end

    def messages_text
      Array(messages).map { "[#{_1[:role]}] #{_1[:content]}" }.join("\n\n")
    end
  end
end
```

- [ ] **Step 14.3: Write the system prompt spec**

Create `spec/lib/narrator/system_prompt_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Narrator::SystemPrompt do
  it "has a non-empty text constant" do
    expect(described_class.text).to be_a(String)
    expect(described_class.text.length).to be > 200
  end

  it "documents the asymmetry contract" do
    expect(described_class.text).to match(/asymmetry|hidden|do not invent|prompt/i)
  end

  it "is frozen so callers cannot mutate it accidentally" do
    expect(described_class.text).to be_frozen
  end
end
```

- [ ] **Step 14.4: Implement `Narrator::SystemPrompt`**

Create `app/lib/narrator/system_prompt.rb`:

```ruby
module Narrator
  module SystemPrompt
    TEXT = <<~MARKDOWN.freeze
      You are the narrator of a solo tabletop role-playing session in the spirit of D&D 5e played with the Mythic GME 2e oracle.

      # Your role

      Describe the world, the consequences of the player's actions, and the responses of NPCs and factions in vivid, second-person prose. Move the fiction forward; do not summarize or recap. The player narrates their own intent and inner life — your prose describes the world they perceive and the immediate outcomes they cause, never what they think or feel.

      # The asymmetry contract

      You only know what is in this prompt. The campaign description, faction roster, and NPC roster you see contain only player-visible information. You do not have access to hidden state — there are no "secret motivations," "hidden clocks," or "true identities" available to you, only the public facts the player would already know or could plausibly observe. You will not invent hidden state on the player's behalf or imply that the player knows something the prompt does not state.

      If the player attempts an action whose outcome is uncertain — combat, a skill check, a question of NPC disposition, a roll on the world — you stop short of the resolution and prompt the player to roll dice or ask the oracle. You do not decide the outcome yourself. Examples:

      - "Roll a Dexterity check to see if you slip past the guard."
      - "Ask the oracle whether the door is locked (likelihood: 50_50)."
      - "Roll 1d20 to attack."

      # Format

      Free-flowing prose. Second person. No meta-commentary, no bullet lists, no rules quotes, no out-of-character asides. Keep responses to 3-6 short paragraphs unless the action genuinely warrants more. End at a natural beat — a question implied, a choice presented, a roll requested — rather than wrapping every paragraph with a leading question.
    MARKDOWN

    def self.text = TEXT
  end
end
```

- [ ] **Step 14.5: Run and confirm pass**

```
bundle exec rspec spec/lib/narrator/prompt_spec.rb spec/lib/narrator/system_prompt_spec.rb
```

- [ ] **Step 14.6: Commit**

```
git add app/lib/narrator/prompt.rb app/lib/narrator/system_prompt.rb spec/lib/narrator/prompt_spec.rb spec/lib/narrator/system_prompt_spec.rb
git commit -m "Add Narrator::Prompt + Narrator::SystemPrompt (Phase 8.14)"
```

---

## Task 15: `Narrator::PromptBuilder`

**Files:**
- Create: `app/lib/narrator/prompt_builder.rb`
- Create: `spec/lib/narrator/prompt_builder_spec.rb`

- [ ] **Step 15.1: Write the spec**

Create `spec/lib/narrator/prompt_builder_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Narrator::PromptBuilder do
  let(:campaign) { create(:campaign, name: "Test Campaign", description: "A short description.") }
  let(:scene)    { create(:scene, campaign: campaign, title: "The Tavern", summary: "A noisy hall.") }
  let!(:faction) { create(:faction, :with_secrets, campaign: campaign, name: "The Cult", public_description: "Allegedly charitable.") }
  let!(:npc)     { create(:npc, :with_secrets, campaign: campaign, name: "Old Tom", public_description: "Bartender.", location: "The Tavern") }

  describe ".call" do
    it "returns a Narrator::Prompt with three system blocks and one user message" do
      prompt = described_class.call(scene: scene, player_action_text: "I look around.")

      expect(prompt).to be_a(Narrator::Prompt)
      expect(prompt.system.length).to eq(3)
      expect(prompt.messages).to eq([{ role: "user", content: "I look around." }])
      expect(prompt.cache_breakpoints).to eq([0, 1])
    end

    it "includes the rules block first" do
      prompt = described_class.call(scene: scene, player_action_text: "x")
      expect(prompt.system[0][:text]).to eq(Narrator::SystemPrompt.text)
    end

    it "includes the campaign and roster in block 1" do
      prompt = described_class.call(scene: scene, player_action_text: "x")
      block = prompt.system[1][:text]
      expect(block).to include("Test Campaign")
      expect(block).to include("A short description.")
      expect(block).to include("The Cult")
      expect(block).to include("Allegedly charitable.")
      expect(block).to include("Old Tom")
      expect(block).to include("Bartender.")
      expect(block).to include("The Tavern")
    end

    it "includes the scene context and recent events in block 2" do
      create(:event, scene: scene, kind: "narration", payload: { "text" => "It is dark." })
      prompt = described_class.call(scene: scene, player_action_text: "x")
      block = prompt.system[2][:text]
      expect(block).to include("The Tavern")
      expect(block).to include("A noisy hall.")
      expect(block).to include("It is dark.")
    end
  end

  describe "#input_view_models" do
    it "returns only Player::* view models" do
      builder = described_class.new(scene: scene, player_action_text: "x")
      vms = builder.input_view_models
      expect(vms).not_to be_empty
      expect(vms).to all(satisfy { |vm| vm.class.name.start_with?("Player::") })
    end
  end

  describe "asymmetry" do
    it "does not leak any faction or NPC secret content into the rendered prompt" do
      prompt = described_class.call(scene: scene, player_action_text: "I look around.")
      expect(prompt.to_s).not_to leak_secrets_of(faction, npc)
    end
  end

  describe "event window truncation" do
    before do
      35.times do |i|
        create(:event, scene: scene, kind: "narration", payload: { "text" => "Event #{i}" }, occurred_at: i.minutes.ago)
      end
    end

    it "includes a truncation marker when more than RECENT_EVENT_WINDOW events exist" do
      prompt = described_class.call(scene: scene, player_action_text: "x")
      block = prompt.system[2][:text]
      expect(block).to include("[5 earlier events truncated for context]")
    end

    it "includes only the last RECENT_EVENT_WINDOW events" do
      prompt = described_class.call(scene: scene, player_action_text: "x")
      block = prompt.system[2][:text]
      # The 5 oldest events should be excluded; sample one.
      expect(block).not_to include("Event 30")
      # The most recent should be included.
      expect(block).to include("Event 0")
    end
  end
end
```

- [ ] **Step 15.2: Run and confirm failure**

```
bundle exec rspec spec/lib/narrator/prompt_builder_spec.rb
```

Expected: undefined constant.

- [ ] **Step 15.3: Implement the builder**

Create `app/lib/narrator/prompt_builder.rb`:

```ruby
module Narrator
  class PromptBuilder
    RECENT_EVENT_WINDOW = 30

    def self.call(scene:, player_action_text:)
      new(scene: scene, player_action_text: player_action_text).call
    end

    def initialize(scene:, player_action_text:)
      @scene = scene
      @player_action_text = player_action_text.to_s
    end

    def call
      Narrator::Prompt.new(
        system: build_system_blocks,
        messages: build_messages,
        cache_breakpoints: [0, 1]
      )
    end

    def input_view_models
      [campaign_vm, scene_vm, *faction_vms, *npc_vms]
    end

    private

    def build_system_blocks
      [
        { type: "text", text: Narrator::SystemPrompt.text },
        { type: "text", text: campaign_and_roster_text },
        { type: "text", text: scene_context_text }
      ]
    end

    def build_messages
      [{ role: "user", content: @player_action_text }]
    end

    def campaign_and_roster_text
      <<~MD.strip
        # Campaign

        Name: #{campaign_vm.name}
        #{campaign_vm.description}

        # Factions

        #{faction_vms.map { faction_md(_1) }.join("\n\n")}

        # NPCs

        #{npc_vms.map { npc_md(_1) }.join("\n\n")}
      MD
    end

    def scene_context_text
      <<~MD.strip
        # Current scene

        Title: #{scene_vm.title}
        #{scene_vm.summary}

        # Recent events (oldest first)

        #{recent_events_md}
      MD
    end

    def recent_events_md
      events = recent_events_window
      lines = []
      lines << "[#{omitted_count} earlier events truncated for context]" if omitted_count.positive?
      lines.concat(events.map { event_md(_1) })
      lines.join("\n\n")
    end

    def recent_events_window
      @recent_events_window ||= scene_vm.events.last(RECENT_EVENT_WINDOW)
    end

    def omitted_count
      [scene_vm.events.size - RECENT_EVENT_WINDOW, 0].max
    end

    def event_md(event_vm)
      "[#{event_vm.kind} @ #{event_vm.occurred_at_label}] #{event_vm.text}"
    end

    def faction_md(vm)
      "## #{vm.name}\n#{vm.public_description}"
    end

    def npc_md(vm)
      base = "## #{vm.name}\n#{vm.public_description}"
      vm.location.present? ? "#{base} (#{vm.location})" : base
    end

    def campaign_vm
      @campaign_vm ||= Player::CampaignViewModel.new(@scene.campaign)
    end

    def scene_vm
      @scene_vm ||= Player::SceneViewModel.new(@scene)
    end

    def faction_vms
      @faction_vms ||= @scene.campaign.factions.order(:name).map { Player::FactionViewModel.new(_1) }
    end

    def npc_vms
      @npc_vms ||= @scene.campaign.npcs.order(:name).map { Player::NpcViewModel.new(_1) }
    end
  end
end
```

- [ ] **Step 15.4: Run and confirm pass**

```
bundle exec rspec spec/lib/narrator/prompt_builder_spec.rb
```

Expected: all green.

- [ ] **Step 15.5: Commit**

```
git add app/lib/narrator/prompt_builder.rb spec/lib/narrator/prompt_builder_spec.rb
git commit -m "Add Narrator::PromptBuilder with asymmetry tests (Phase 8.15)"
```

---

## Task 16: `Narrator::AuditSystemPrompt`

**Files:**
- Create: `app/lib/narrator/audit_system_prompt.rb`
- Create: `spec/lib/narrator/audit_system_prompt_spec.rb`

- [ ] **Step 16.1: Write the spec**

Create `spec/lib/narrator/audit_system_prompt_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Narrator::AuditSystemPrompt do
  it "has a non-empty text constant" do
    expect(described_class.text).to be_a(String)
    expect(described_class.text.length).to be > 200
  end

  it "names all four discipline criteria" do
    text = described_class.text
    %w[player_agency follow_through over_narration_of_intent mechanical_handoff].each do |name|
      expect(text).to include(name)
    end
  end

  it "specifies the JSON output schema" do
    expect(described_class.text).to include("verdict")
    expect(described_class.text).to include("criteria")
    expect(described_class.text).to include("summary")
  end

  it "is frozen" do
    expect(described_class.text).to be_frozen
  end
end
```

- [ ] **Step 16.2: Implement**

Create `app/lib/narrator/audit_system_prompt.rb`:

```ruby
module Narrator
  module AuditSystemPrompt
    TEXT = <<~MARKDOWN.freeze
      You audit a single scene of solo tabletop role-playing for narrator discipline.

      The scene transcript follows in the user message. Each event is labeled with kind, timestamp, and content. Read the entire transcript, then produce a structured verdict in the JSON format below.

      # Criteria

      Assess the narrator on these four criteria, each independently:

      1. **player_agency** — Did the narrator give the player meaningful choices? Or did the narrator dictate player actions, decide outcomes the player should have decided, or close down the player's options without invitation?

      2. **follow_through** — Did the narrator pick up on what the player declared and develop it? Or did the narrator drop player declarations, ignore stated intent, or pivot to unrelated business?

      3. **over_narration_of_intent** — Did the narrator describe the world the player perceives, or did the narrator narrate what the player thinks, feels, intends, or knows? The player narrates inner life; the narrator describes the outer world.

      4. **mechanical_handoff** — When uncertainty arose in the fiction (a check, a question of NPC disposition, an attack), did the narrator stop short and request a roll or oracle question? Or did the narrator resolve the uncertainty narratively?

      For each criterion, give a status of `pass`, `concerns`, or `fail`, plus a one-sentence note grounded in a specific event from the transcript.

      # Verdict aggregation

      The overall `verdict` is:
      - `pass` if all four criteria are `pass`.
      - `fail` if any criterion is `fail`.
      - `concerns` otherwise.

      # Output format

      Respond with ONLY a JSON object matching this schema. No prose before or after, no markdown fences. Just the object.

      ```json
      {
        "verdict": "pass" | "concerns" | "fail",
        "criteria": [
          { "name": "player_agency",            "status": "pass" | "concerns" | "fail", "note": "..." },
          { "name": "follow_through",           "status": "pass" | "concerns" | "fail", "note": "..." },
          { "name": "over_narration_of_intent", "status": "pass" | "concerns" | "fail", "note": "..." },
          { "name": "mechanical_handoff",       "status": "pass" | "concerns" | "fail", "note": "..." }
        ],
        "summary": "1-2 sentences on the overall pattern."
      }
      ```
    MARKDOWN

    def self.text = TEXT
  end
end
```

- [ ] **Step 16.3: Run and confirm pass**

```
bundle exec rspec spec/lib/narrator/audit_system_prompt_spec.rb
```

- [ ] **Step 16.4: Commit**

```
git add app/lib/narrator/audit_system_prompt.rb spec/lib/narrator/audit_system_prompt_spec.rb
git commit -m "Add Narrator::AuditSystemPrompt (Phase 8.16)"
```

---

## Task 17: `Narrator::AuditPromptBuilder`

**Files:**
- Create: `app/lib/narrator/audit_prompt_builder.rb`
- Create: `spec/lib/narrator/audit_prompt_builder_spec.rb`

- [ ] **Step 17.1: Write the spec**

Create `spec/lib/narrator/audit_prompt_builder_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Narrator::AuditPromptBuilder do
  let(:scene) { create(:scene, title: "The Tavern", summary: "A noisy hall.") }

  before do
    create(:event, scene: scene, kind: "player_action", payload: { "text" => "I open the door." }, occurred_at: 2.minutes.ago)
    create(:event, scene: scene, kind: "narration",     payload: { "text" => "The door swings open." }, occurred_at: 1.minute.ago)
  end

  describe ".call" do
    it "returns a Narrator::Prompt" do
      prompt = described_class.call(scene: scene)
      expect(prompt).to be_a(Narrator::Prompt)
    end

    it "puts AuditSystemPrompt.text in the cached system block" do
      prompt = described_class.call(scene: scene)
      expect(prompt.system.length).to eq(1)
      expect(prompt.system[0][:text]).to eq(Narrator::AuditSystemPrompt.text)
      expect(prompt.cache_breakpoints).to eq([0])
    end

    it "renders all events in the user message ordered by occurred_at" do
      prompt = described_class.call(scene: scene)
      content = prompt.messages.first[:content]
      expect(content).to include("The Tavern")
      expect(content).to include("[player_action")
      expect(content).to include("I open the door.")
      expect(content.index("I open the door.")).to be < content.index("The door swings open.")
    end
  end

  describe "asymmetry" do
    let!(:faction) { create(:faction, :with_secrets, campaign: scene.campaign) }
    let!(:npc)     { create(:npc, :with_secrets, campaign: scene.campaign) }

    it "does not leak secrets in the audit prompt (transitively guaranteed)" do
      prompt = described_class.call(scene: scene)
      expect(prompt.to_s).not_to leak_secrets_of(faction, npc)
    end
  end
end
```

- [ ] **Step 17.2: Implement**

Create `app/lib/narrator/audit_prompt_builder.rb`:

```ruby
module Narrator
  class AuditPromptBuilder
    def self.call(scene:)
      new(scene: scene).call
    end

    def initialize(scene:)
      @scene = scene
    end

    def call
      Narrator::Prompt.new(
        system: [{ type: "text", text: Narrator::AuditSystemPrompt.text }],
        messages: [{ role: "user", content: scene_transcript }],
        cache_breakpoints: [0]
      )
    end

    private

    def scene_transcript
      vm = Narrator::SceneAuditViewModel.new(@scene)
      header = "# Scene: #{vm.title}\n\n#{vm.summary}\n\n# Events\n\n"
      header + vm.events.map { event_line(_1) }.join("\n\n")
    end

    def event_line(event_vm)
      "[#{event_vm.kind} @ #{event_vm.occurred_at_label}]\n#{event_vm.text}"
    end
  end
end
```

- [ ] **Step 17.3: Run and confirm pass**

```
bundle exec rspec spec/lib/narrator/audit_prompt_builder_spec.rb
```

- [ ] **Step 17.4: Commit**

```
git add app/lib/narrator/audit_prompt_builder.rb spec/lib/narrator/audit_prompt_builder_spec.rb
git commit -m "Add Narrator::AuditPromptBuilder (Phase 8.17)"
```

---

## Task 18: Add `spec/support/turbo_streams.rb` capture helper

**Files:**
- Create: `spec/support/turbo_streams.rb`

- [ ] **Step 18.1: Implement the helper**

Create `spec/support/turbo_streams.rb`:

```ruby
# Capture Turbo::StreamsChannel.broadcast_replace_to / broadcast_append_to /
# broadcast_remove_to calls for assertion in job specs without standing up
# an ActionCable subscriber.
module TurboStreamsCaptureHelpers
  def captured_turbo_broadcasts
    @captured_turbo_broadcasts ||= []
  end

  def install_turbo_capture!
    %i[broadcast_replace_to broadcast_append_to broadcast_remove_to broadcast_update_to].each do |method|
      allow(Turbo::StreamsChannel).to receive(method) do |*args, **kwargs|
        captured_turbo_broadcasts << { method: method, args: args, kwargs: kwargs }
      end
    end
  end
end

RSpec.configure do |c|
  c.include TurboStreamsCaptureHelpers, type: :job
end
```

(No spec needed — exercised by the job specs in Tasks 19-20.)

- [ ] **Step 18.2: Commit**

```
git add spec/support/turbo_streams.rb
git commit -m "Add spec/support/turbo_streams.rb capture helper (Phase 8.18)"
```

---

## Task 19: `NarrationJob`

**Files:**
- Create: `app/jobs/narration_job.rb`
- Create: `spec/jobs/narration_job_spec.rb`

- [ ] **Step 19.1: Write the spec**

Create `spec/jobs/narration_job_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe NarrationJob, type: :job do
  let(:user)          { create(:user) }
  let(:campaign)      { create(:campaign, user: user) }
  let(:scene)         { create(:scene, campaign: campaign) }
  let!(:player_event) {
    create(:event, scene: scene, kind: "player_action",
           payload: { "text" => "I open the door." })
  }
  let!(:narration_event) {
    create(:event, scene: scene, kind: "narration",
           payload: { "text" => "", "status" => "streaming",
                      "player_action_event_id" => player_event.id, "llm_call_id" => nil })
  }

  before do
    install_turbo_capture!
    allow(Rails.application.credentials).to receive(:dig).with(:anthropic, :api_key).and_return("sk-test")
    Llm::Providers::Anthropic.reset_client!
  end

  describe "happy path" do
    before do
      stub_anthropic_streaming(text_chunks: ["Hello ", "there", "."],
                               input_tokens: 10, output_tokens: 4)
    end

    it "accumulates text and finalizes the narration event payload" do
      described_class.perform_now(narration_event.id)
      narration_event.reload

      expect(narration_event.payload["text"]).to eq("Hello there.")
      expect(narration_event.payload["status"]).to eq("complete")
      expect(narration_event.payload["llm_call_id"]).to be_a(Integer)
    end

    it "writes an LlmCall row" do
      expect {
        described_class.perform_now(narration_event.id)
      }.to change(LlmCall, :count).by(1)

      call = LlmCall.last
      expect(call.purpose).to eq("narration")
      expect(call.scene_id).to eq(scene.id)
    end

    it "broadcasts at least one replace to the per-(scene, user) channel" do
      described_class.perform_now(narration_event.id)
      replaces = captured_turbo_broadcasts.select { _1[:method] == :broadcast_replace_to }
      expect(replaces).not_to be_empty
      expect(replaces.first[:args]).to eq([[scene, user]])
      expect(replaces.first[:kwargs][:target]).to include("event_#{narration_event.id}")
    end
  end

  describe "error path" do
    before { stub_anthropic_streaming_error(status: 500, message: "boom") }

    it "marks the narration event as errored and persists an LlmCall" do
      described_class.perform_now(narration_event.id)
      narration_event.reload

      expect(narration_event.payload["status"]).to eq("errored")
      expect(narration_event.payload["error_message"]).to include("boom")
      expect(narration_event.payload["llm_call_id"]).to be_a(Integer)
    end
  end
end
```

- [ ] **Step 19.2: Run and confirm failure**

```
bundle exec rspec spec/jobs/narration_job_spec.rb
```

Expected: undefined constant.

- [ ] **Step 19.3: Implement the job**

Create `app/jobs/narration_job.rb`:

```ruby
class NarrationJob < ApplicationJob
  queue_as :narration

  FLUSH_MS    = 80
  FLUSH_BYTES = 25

  def perform(narration_event_id)
    narration_event = Event.find(narration_event_id)
    scene           = narration_event.scene
    campaign        = scene.campaign
    user            = campaign.user
    player_action   = Event.find(narration_event.payload.fetch("player_action_event_id"))

    prompt = Narrator::PromptBuilder.call(
      scene: scene,
      player_action_text: player_action.payload.fetch("text")
    )

    accumulator = +""
    buffer      = +""
    last_flush  = monotonic_ms

    llm_call = Llm::Call.execute_streaming(
      purpose: :narration,
      user: user, campaign: campaign, scene: scene,
      **prompt.to_call_kwargs
    ) do |text:|
      accumulator << text
      buffer      << text
      now = monotonic_ms
      if now - last_flush >= FLUSH_MS || buffer.bytesize >= FLUSH_BYTES
        flush(narration_event, accumulator, status: "streaming")
        buffer.clear
        last_flush = now
      end
    end

    if llm_call.successful?
      finalize_success(narration_event, accumulator, llm_call)
    else
      finalize_error(narration_event, accumulator, llm_call)
    end
  end

  private

  def flush(event, text, status:)
    event.with_lock do
      event.update!(payload: event.payload.merge("text" => text, "status" => status))
    end
    broadcast_replace(event)
  end

  def finalize_success(event, text, llm_call)
    event.with_lock do
      event.update!(payload: event.payload.merge(
        "text" => text, "status" => "complete", "llm_call_id" => llm_call.id
      ))
    end
    broadcast_replace(event)
  end

  def finalize_error(event, text, llm_call)
    event.with_lock do
      event.update!(payload: event.payload.merge(
        "text" => text, "status" => "errored",
        "llm_call_id" => llm_call.id,
        "error_message" => llm_call.error_message
      ))
    end
    broadcast_replace(event)
  end

  def broadcast_replace(event)
    Turbo::StreamsChannel.broadcast_replace_to(
      [event.scene, event.scene.campaign.user],
      target: ActionView::RecordIdentifier.dom_id(event),
      renderable: Play::Events::NarrationComponent.new(event: event)
    )
  end

  def monotonic_ms
    (Process.clock_gettime(Process::CLOCK_MONOTONIC) * 1000).to_i
  end
end
```

- [ ] **Step 19.4: Run and confirm pass**

```
bundle exec rspec spec/jobs/narration_job_spec.rb
```

Expected: all green. If `broadcast_replace_to` complains about the `renderable:` kwarg, fall back to `html: Play::Events::NarrationComponent.new(event: event).render_in(ApplicationController.renderer)` — but verify the kwarg first by reading `vendor/bundle/.../turbo-rails/.../broadcastable.rb`.

- [ ] **Step 19.5: Commit**

```
git add app/jobs/narration_job.rb spec/jobs/narration_job_spec.rb
git commit -m "Add NarrationJob with chunk batching + Turbo Stream replace broadcasts (Phase 8.19)"
```

---

## Task 20: `SceneAuditJob`

**Files:**
- Create: `app/jobs/scene_audit_job.rb`
- Create: `spec/jobs/scene_audit_job_spec.rb`

- [ ] **Step 20.1: Write the spec**

Create `spec/jobs/scene_audit_job_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe SceneAuditJob, type: :job do
  let(:scene) { create(:scene, closed_at: Time.current) }

  before do
    create(:event, scene: scene, kind: "player_action", payload: { "text" => "I look around." })
    create(:event, scene: scene, kind: "narration",     payload: { "text" => "It is dark." })

    allow(Rails.application.credentials).to receive(:dig).with(:anthropic, :api_key).and_return("sk-test")
    Llm::Providers::Anthropic.reset_client!
  end

  describe "happy path with valid JSON response" do
    let(:audit_json) {
      {
        verdict: "pass",
        criteria: [
          { name: "player_agency",            status: "pass", note: "ok" },
          { name: "follow_through",           status: "pass", note: "ok" },
          { name: "over_narration_of_intent", status: "pass", note: "ok" },
          { name: "mechanical_handoff",       status: "pass", note: "ok" }
        ],
        summary: "All good."
      }.to_json
    }

    before do
      stub_request(:post, "https://api.anthropic.com/v1/messages").to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          id: "msg_audit_1", type: "message", role: "assistant", model: "claude-sonnet-4-6",
          content: [{ type: "text", text: audit_json }],
          stop_reason: "end_turn", stop_sequence: nil,
          usage: { input_tokens: 100, output_tokens: 200,
                   cache_creation_input_tokens: 0, cache_read_input_tokens: 0 }
        }.to_json
      )
    end

    it "creates a SceneAudit row with verdict pass and the parsed result" do
      expect {
        described_class.perform_now(scene.id)
      }.to change(SceneAudit, :count).by(1)

      audit = scene.reload.audit
      expect(audit.verdict).to eq("pass")
      expect(audit.result["summary"]).to eq("All good.")
      expect(audit.llm_call.purpose).to eq("bookkeeper_audit")
    end
  end

  describe "JSON parse failure" do
    before do
      stub_request(:post, "https://api.anthropic.com/v1/messages").to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          id: "msg_audit_2", type: "message", role: "assistant", model: "claude-sonnet-4-6",
          content: [{ type: "text", text: "definitely not json" }],
          stop_reason: "end_turn", stop_sequence: nil,
          usage: { input_tokens: 50, output_tokens: 5,
                   cache_creation_input_tokens: 0, cache_read_input_tokens: 0 }
        }.to_json
      )
    end

    it "creates a SceneAudit row with verdict fail and error info" do
      described_class.perform_now(scene.id)
      audit = scene.reload.audit
      expect(audit.verdict).to eq("fail")
      expect(audit.result["error"]).to eq("audit_parse_failed")
      expect(audit.result["raw"]).to include("definitely not json")
    end
  end

  describe "idempotency" do
    let(:audit_json) {
      { verdict: "pass", criteria: [], summary: "ok" }.to_json
    }

    before do
      stub_request(:post, "https://api.anthropic.com/v1/messages").to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          id: "msg_audit_3", type: "message", role: "assistant", model: "claude-sonnet-4-6",
          content: [{ type: "text", text: audit_json }],
          stop_reason: "end_turn", stop_sequence: nil,
          usage: { input_tokens: 1, output_tokens: 1,
                   cache_creation_input_tokens: 0, cache_read_input_tokens: 0 }
        }.to_json
      )
    end

    it "is a no-op on the second call when an audit exists" do
      described_class.perform_now(scene.id)
      expect {
        described_class.perform_now(scene.id)
      }.not_to change(SceneAudit, :count)
    end
  end
end
```

- [ ] **Step 20.2: Run and confirm failure**

```
bundle exec rspec spec/jobs/scene_audit_job_spec.rb
```

Expected: undefined constant.

- [ ] **Step 20.3: Implement**

Create `app/jobs/scene_audit_job.rb`:

```ruby
class SceneAuditJob < ApplicationJob
  queue_as :default

  def perform(scene_id)
    scene = Scene.find(scene_id)
    return if scene.audit.present?

    prompt = Narrator::AuditPromptBuilder.call(scene: scene)

    llm_call = Llm::Call.execute(
      purpose: :bookkeeper_audit,
      user: scene.campaign.user, campaign: scene.campaign, scene: scene,
      max_tokens: 2048,
      **prompt.to_call_kwargs
    )

    parsed = parse_audit_result(llm_call)

    SceneAudit.create!(
      scene: scene,
      llm_call: llm_call,
      verdict: parsed.fetch(:verdict),
      result: parsed.fetch(:result)
    )
  end

  private

  def parse_audit_result(llm_call)
    return failed(llm_call, "call_failed") unless llm_call.successful?

    raw = llm_call.text.to_s
    json = extract_json(raw)
    parsed = JSON.parse(json)

    verdict = parsed.fetch("verdict")
    raise KeyError unless %w[pass concerns fail].include?(verdict)

    { verdict: verdict, result: parsed }
  rescue JSON::ParserError, KeyError
    failed(llm_call, "audit_parse_failed", raw: llm_call.text)
  end

  def failed(llm_call, error_kind, raw: nil)
    {
      verdict: "fail",
      result: {
        "error" => error_kind,
        "raw"   => raw,
        "llm_call_error" => llm_call.error_message
      }.compact
    }
  end

  def extract_json(text)
    # Models occasionally wrap JSON in ```json fences. Strip non-brace prefix/suffix.
    body = text.to_s.strip
    body = body.sub(/\A.*?(\{)/m, '\1')
    body = body.sub(/(\}).*?\z/m, '\1')
    body
  end
end
```

- [ ] **Step 20.4: Run and confirm pass**

```
bundle exec rspec spec/jobs/scene_audit_job_spec.rb
```

- [ ] **Step 20.5: Commit**

```
git add app/jobs/scene_audit_job.rb spec/jobs/scene_audit_job_spec.rb
git commit -m "Add SceneAuditJob with structured-output parsing (Phase 8.20)"
```

---

## Task 21: `Play::Narration::FormComponent`

**Files:**
- Create: `app/components/play/narration/form_component.rb`
- Create: `app/components/play/narration/form_component.html.erb`
- Create: `spec/components/play/narration/form_component_spec.rb`

- [ ] **Step 21.1: Write the spec**

Create `spec/components/play/narration/form_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Play::Narration::FormComponent, type: :component do
  let(:scene) { create(:scene) }

  it "renders a textarea, submit button, and helper text" do
    rendered = render_inline(described_class.new(scene: scene))
    expect(rendered.css("textarea[name='narration[text]']")).to be_present
    expect(rendered.css("button[type='submit']")).to be_present
    expect(rendered.text).to include("⌘+Enter to send").or include("Cmd+Enter to send")
  end

  it "carries the dom_id for stream targeting" do
    rendered = render_inline(described_class.new(scene: scene))
    expect(rendered.css("##{ActionView::RecordIdentifier.dom_id(scene, :narration_form)}")).to be_present
  end

  it "preserves sticky text on validation error" do
    rendered = render_inline(described_class.new(scene: scene, text: "I open the door.", error: "be more specific"))
    expect(rendered.css("textarea").text).to include("I open the door.")
    expect(rendered.text).to include("be more specific")
  end

  describe "asymmetry" do
    let!(:faction) { create(:faction, :with_secrets, campaign: scene.campaign) }
    let!(:npc)     { create(:npc, :with_secrets, campaign: scene.campaign) }

    it "does not leak secrets" do
      rendered = render_inline(described_class.new(scene: scene)).to_s
      expect(rendered).not_to leak_secrets_of(faction, npc)
    end
  end
end
```

- [ ] **Step 21.2: Implement the component**

Create `app/components/play/narration/form_component.rb`:

```ruby
module Play
  module Narration
    class FormComponent < ViewComponent::Base
      def initialize(scene:, text: "", error: nil)
        @scene = scene
        @text  = text.to_s
        @error = error
      end

      attr_reader :scene, :text, :error

      def form_dom_id
        helpers.dom_id(scene, :narration_form)
      end

      def submit_path
        helpers.play_campaign_scene_narrations_path(scene.campaign, scene)
      end
    end
  end
end
```

Create `app/components/play/narration/form_component.html.erb`:

```erb
<div id="<%= form_dom_id %>" class="rounded-lg border border-slate-700 bg-slate-900/50 p-4"
     data-controller="narration-form">
  <%= form_with url: submit_path, method: :post, data: { turbo: true } do |f| %>
    <label class="block text-xs uppercase tracking-widest text-slate-500 mb-2">
      What do you do?
    </label>
    <%= f.text_area :text,
        value: text,
        rows: 3,
        placeholder: "Narrate your action…",
        data: { narration_form_target: "text",
                action: "input->narration-form#autosize keydown->narration-form#handleKeydown" },
        class: "w-full resize-none bg-slate-950 border border-slate-700 text-slate-100 rounded p-2 focus:border-amber-500 focus:outline-none" %>
    <% if error.present? %>
      <p class="mt-2 text-sm text-rose-400"><%= error %></p>
    <% end %>
    <div class="mt-2 flex items-center justify-between">
      <p class="text-xs text-slate-500">⌘+Enter to send</p>
      <%= f.submit "Narrate",
          class: "rounded bg-amber-600 px-4 py-2 text-sm font-medium text-slate-50 hover:bg-amber-500" %>
    </div>
  <% end %>
</div>
```

- [ ] **Step 21.3: Run and confirm pass**

```
bundle exec rspec spec/components/play/narration/form_component_spec.rb
```

Expected: textarea/button/helper present; sticky text + error rendered; asymmetry holds. The route helper `play_campaign_scene_narrations_path` does not exist yet — the spec will fail on `submit_path` evaluation. Defer the assertion that uses it (`render_inline`) until Task 25 wires the route. For now, comment out the `render_inline`-using examples and assert on simpler accessors. Alternative: skip the spec until Task 25 and run both together.

(Cleaner approach: write the route stub now. Skip step 21.3, jump to Task 25 to define the route, then return to step 21.3.)

- [ ] **Step 21.4: Commit**

```
git add app/components/play/narration/form_component.rb app/components/play/narration/form_component.html.erb spec/components/play/narration/form_component_spec.rb
git commit -m "Add Play::Narration::FormComponent (Phase 8.21)"
```

---

## Task 22: `Play::Events::PlayerActionComponent` + REGISTRY update

**Files:**
- Create: `app/components/play/events/player_action_component.rb`
- Create: `app/components/play/events/player_action_component.html.erb`
- Modify: `app/components/play/events/component.rb`
- Create: `spec/components/play/events/player_action_component_spec.rb`
- Modify: `spec/components/play/events/component_spec.rb`

- [ ] **Step 22.1: Write the failing component spec**

Create `spec/components/play/events/player_action_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Play::Events::PlayerActionComponent, type: :component do
  let(:scene) { create(:scene) }
  let(:event) {
    create(:event, scene: scene, kind: "player_action",
           payload: { "text" => "I open the door." })
  }

  it "renders the player text" do
    rendered = render_inline(described_class.new(event: event))
    expect(rendered.text).to include("I open the door.")
  end

  it "renders a relative timestamp" do
    travel_to Time.zone.parse("2026-05-14T20:00:00Z") do
      e = create(:event, scene: scene, kind: "player_action",
                 payload: { "text" => "x" }, occurred_at: 5.minutes.ago)
      rendered = render_inline(described_class.new(event: e))
      expect(rendered.text).to include("ago")
    end
  end

  it "carries the event's dom_id for stream targeting" do
    rendered = render_inline(described_class.new(event: event))
    expect(rendered.css("##{ActionView::RecordIdentifier.dom_id(event)}")).to be_present
  end

  describe "asymmetry" do
    let!(:faction) { create(:faction, :with_secrets, campaign: scene.campaign) }
    let!(:npc)     { create(:npc, :with_secrets, campaign: scene.campaign) }

    it "does not leak secrets" do
      rendered = render_inline(described_class.new(event: event)).to_s
      expect(rendered).not_to leak_secrets_of(faction, npc)
    end
  end
end
```

- [ ] **Step 22.2: Implement the component**

Create `app/components/play/events/player_action_component.rb`:

```ruby
module Play
  module Events
    class PlayerActionComponent < ViewComponent::Base
      def initialize(event:)
        @event = event
      end

      attr_reader :event

      def text
        event.payload["text"].to_s
      end

      def relative_time
        helpers.time_ago_in_words(event.occurred_at) + " ago"
      end

      def dom_id
        helpers.dom_id(event)
      end
    end
  end
end
```

Create `app/components/play/events/player_action_component.html.erb`:

```erb
<div id="<%= dom_id %>" class="py-2 pl-4 border-l-2 border-amber-700 my-2">
  <p class="text-xs uppercase tracking-widest text-amber-700">You</p>
  <p class="mt-1 text-slate-300 italic"><%= text %></p>
  <p class="mt-1 text-xs text-slate-600"><%= relative_time %></p>
</div>
```

- [ ] **Step 22.3: Update REGISTRY**

Edit `app/components/play/events/component.rb`. Replace the REGISTRY block:

```ruby
REGISTRY = {
  "narration"        => NarrationComponent,
  "player_action"    => PlayerActionComponent,
  "dice_roll"        => DiceRollComponent,
  "oracle_query"     => OracleQueryComponent,
  "scene_transition" => SceneTransitionComponent
}.freeze
```

- [ ] **Step 22.4: Update the dispatcher spec**

Edit `spec/components/play/events/component_spec.rb`. Add to the "happy path" group:

```ruby
it "resolves player_action to PlayerActionComponent" do
  scene = create(:scene)
  event = create(:event, scene: scene, kind: "player_action", payload: { "text" => "x" })
  expect(described_class.for(event)).to eq(Play::Events::PlayerActionComponent)
end
```

- [ ] **Step 22.5: Run and confirm pass**

```
bundle exec rspec spec/components/play/events/player_action_component_spec.rb spec/components/play/events/component_spec.rb
```

- [ ] **Step 22.6: Commit**

```
git add app/components/play/events/player_action_component.rb app/components/play/events/player_action_component.html.erb app/components/play/events/component.rb spec/components/play/events/player_action_component_spec.rb spec/components/play/events/component_spec.rb
git commit -m "Add Play::Events::PlayerActionComponent + register in REGISTRY (Phase 8.22)"
```

---

## Task 23: Status branches on `Play::Events::NarrationComponent`

**Files:**
- Modify: `app/components/play/events/narration_component.rb`
- Modify: `app/components/play/events/narration_component.html.erb`
- Modify: `spec/components/play/events/narration_component_spec.rb`

- [ ] **Step 23.1: Write the failing tests**

Add to `spec/components/play/events/narration_component_spec.rb`:

```ruby
describe "status branches" do
  let(:scene) { create(:scene) }

  it "renders a streaming cursor when status is streaming" do
    event = create(:event, scene: scene, kind: "narration",
                   payload: { "text" => "Halfway through", "status" => "streaming" })
    rendered = render_inline(described_class.new(event: event))
    expect(rendered.text).to include("Halfway through")
    expect(rendered.css("[data-narration-status='streaming']")).to be_present
  end

  it "renders the final text when status is complete" do
    event = create(:event, scene: scene, kind: "narration",
                   payload: { "text" => "All done.", "status" => "complete" })
    rendered = render_inline(described_class.new(event: event))
    expect(rendered.text).to include("All done.")
    expect(rendered.css("[data-narration-status='streaming']")).to be_empty
  end

  it "renders an error state when status is errored" do
    event = create(:event, scene: scene, kind: "narration",
                   payload: { "text" => "Partial",
                              "status" => "errored",
                              "error_message" => "boom" })
    rendered = render_inline(described_class.new(event: event))
    expect(rendered.text).to include("Partial")
    expect(rendered.text).to include("the narrator couldn't finish")
    expect(rendered.css(".border-rose-700, .border-rose-600")).not_to be_empty
  end
end
```

- [ ] **Step 23.2: Update the component class**

Edit `app/components/play/events/narration_component.rb`:

```ruby
module Play
  module Events
    class NarrationComponent < ViewComponent::Base
      def initialize(event:)
        @event = event
      end

      attr_reader :event

      def text
        event.payload["text"].to_s
      end

      def status
        event.payload["status"].to_s
      end

      def error_message
        event.payload["error_message"].to_s
      end

      def relative_time
        helpers.time_ago_in_words(event.occurred_at) + " ago"
      end

      def dom_id
        helpers.dom_id(event)
      end
    end
  end
end
```

- [ ] **Step 23.3: Update the template**

Replace `app/components/play/events/narration_component.html.erb`:

```erb
<div id="<%= dom_id %>" class="py-3 <%= 'rounded border border-rose-700 bg-rose-900/20 p-3' if status == 'errored' %>">
  <% if status == 'errored' %>
    <p class="text-xs uppercase tracking-widest text-rose-400">Narrator error</p>
  <% end %>

  <p class="text-slate-200 leading-relaxed">
    <%= text %><%= '…' if status == 'streaming' %>
    <% if status == 'streaming' %>
      <span data-narration-status="streaming"
            class="inline-block w-2 h-4 align-middle ml-1 bg-amber-500 animate-pulse"></span>
    <% end %>
  </p>

  <% if status == 'errored' && error_message.present? %>
    <p class="mt-2 text-sm text-rose-300">
      the narrator couldn't finish — <%= error_message %>. try again.
    </p>
  <% end %>

  <p class="mt-1 text-xs text-slate-600"><%= relative_time %></p>
</div>
```

- [ ] **Step 23.4: Run and confirm pass**

```
bundle exec rspec spec/components/play/events/narration_component_spec.rb
```

- [ ] **Step 23.5: Commit**

```
git add app/components/play/events/narration_component.rb app/components/play/events/narration_component.html.erb spec/components/play/events/narration_component_spec.rb
git commit -m "Add streaming/errored status branches to NarrationComponent (Phase 8.23)"
```

---

## Task 24: Add `narrations` route + `Play::NarrationsController`

**Files:**
- Modify: `config/routes/play.rb`
- Create: `app/controllers/play/narrations_controller.rb`
- Create: `spec/requests/play/narrations_spec.rb`

- [ ] **Step 24.1: Add the nested route**

Edit `config/routes/play.rb`. In the `resources :scenes, only: []` block, add:

```ruby
resources :narrations, only: [:create]
```

So the block reads:

```ruby
resources :scenes, only: [] do
  member { get :play }
  resources :dice_rolls,     only: [:create]
  resources :oracle_queries, only: [:create]
  resources :narrations,     only: [:create]
end
```

- [ ] **Step 24.2: Sanity-check the route**

```
bin/rails routes -g narrations
```

Expected: a `POST /campaigns/:campaign_id/scenes/:scene_id/narrations` route named `play_campaign_scene_narrations`.

- [ ] **Step 24.3: Write the request spec**

Create `spec/requests/play/narrations_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Play::Narrations", type: :request do
  let(:user)     { create(:user) }
  let(:campaign) { create(:campaign, user: user) }
  let(:scene)    { create(:scene, campaign: campaign) }

  let(:other_user)     { create(:user) }
  let(:other_campaign) { create(:campaign, user: other_user) }
  let(:other_scene)    { create(:scene, campaign: other_campaign) }

  before { sign_in user }

  describe "POST /campaigns/:cid/scenes/:sid/narrations" do
    let(:path) { play_campaign_scene_narrations_path(campaign, scene) }

    it "creates a player_action and a narration event in order" do
      expect {
        post path, params: { narration: { text: "I open the door." } },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
      }.to change(Event, :count).by(2).and change(scene.events, :count).by(2)

      events = scene.events.order(:occurred_at)
      expect(events.first.kind).to eq("player_action")
      expect(events.first.payload["text"]).to eq("I open the door.")
      expect(events.last.kind).to eq("narration")
      expect(events.last.payload["status"]).to eq("streaming")
      expect(events.last.payload["player_action_event_id"]).to eq(events.first.id)
      expect(events.first.payload["narration_event_id"]).to eq(events.last.id)
    end

    it "enqueues a NarrationJob for the new narration event" do
      expect {
        post path, params: { narration: { text: "x" } },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
      }.to have_enqueued_job(NarrationJob)
    end

    it "returns turbo_stream with appends + replace + remove" do
      post path, params: { narration: { text: "x" } },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("turbo-stream")
      expect(response.body).to include('action="append"')
      expect(response.body).to include('action="replace"')
    end

    it "returns 422 with re-rendered form on empty text" do
      expect {
        post path, params: { narration: { text: "  " } },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
      }.not_to change(Event, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("type something")
    end

    it "returns 404 for cross-user campaign access" do
      expect {
        post play_campaign_scene_narrations_path(other_campaign, other_scene),
             params: { narration: { text: "x" } },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
```

- [ ] **Step 24.4: Implement the controller**

Create `app/controllers/play/narrations_controller.rb`:

```ruby
module Play
  class NarrationsController < ::ApplicationController
    before_action :load_scene

    def create
      text = params.require(:narration).permit(:text).fetch(:text, "").to_s.strip

      if text.blank?
        return render turbo_stream: turbo_stream.replace(
          dom_id_for_narration_form,
          Play::Narration::FormComponent.new(scene: @scene, text: text, error: "type something to do")
        ), status: :unprocessable_content
      end

      player_action_event = nil
      narration_event     = nil

      Event.transaction do
        player_action_event = @scene.events.create!(
          kind: "player_action",
          payload: { "text" => text, "narration_event_id" => nil }
        )
        narration_event = @scene.events.create!(
          kind: "narration",
          payload: {
            "text" => "", "status" => "streaming", "llm_call_id" => nil,
            "player_action_event_id" => player_action_event.id
          }
        )
        player_action_event.update!(payload: player_action_event.payload.merge(
          "narration_event_id" => narration_event.id
        ))
      end

      NarrationJob.perform_later(narration_event.id)

      respond_to do |f|
        f.turbo_stream { render turbo_stream: stream_appends_and_form_reset(player_action_event, narration_event) }
        f.html { redirect_to play_campaign_scene_path(@scene.campaign, @scene) }
      end
    end

    private

    def load_scene
      @scene = current_user.campaigns.find(params[:campaign_id]).scenes.find(params[:scene_id])
    end

    def stream_appends_and_form_reset(player_action_event, narration_event)
      [
        turbo_stream.append(dom_id_for_log,
                            Play::Events::Component.for(player_action_event).new(event: player_action_event)),
        turbo_stream.append(dom_id_for_log,
                            Play::Events::Component.for(narration_event).new(event: narration_event)),
        turbo_stream.remove(dom_id_for_log_empty),
        turbo_stream.replace(dom_id_for_narration_form,
                             Play::Narration::FormComponent.new(scene: @scene))
      ]
    end

    def dom_id_for_log
      view_context.dom_id(@scene, :log)
    end

    def dom_id_for_log_empty
      view_context.dom_id(@scene, :log_empty)
    end

    def dom_id_for_narration_form
      view_context.dom_id(@scene, :narration_form)
    end
  end
end
```

- [ ] **Step 24.5: Run and confirm pass**

```
bundle exec rspec spec/requests/play/narrations_spec.rb spec/components/play/narration/form_component_spec.rb
```

Expected: all green. (The form component spec from Task 21 now resolves the route helper.)

- [ ] **Step 24.6: Commit**

```
git add config/routes/play.rb app/controllers/play/narrations_controller.rb spec/requests/play/narrations_spec.rb
git commit -m "Add Play::NarrationsController + route (Phase 8.24)"
```

---

## Task 25: Render the narration form in `Play::Scenes::PlayComponent`

**Files:**
- Modify: `app/components/play/scenes/play_component.html.erb`
- Modify: `spec/components/play/scenes/play_component_spec.rb`

- [ ] **Step 25.1: Update the play component template**

Edit `app/components/play/scenes/play_component.html.erb`. Replace the body section to insert the narration form above the existing input dock:

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

    <div data-controller="scene-log-scroll">
      <%= render Play::Scenes::LogComponent.new(scene: scene) %>
    </div>

    <div class="mt-8">
      <%= render Play::Narration::FormComponent.new(scene: scene) %>
    </div>

    <%= render Play::Scenes::InputDockComponent.new(scene: scene) %>
  </div>
</div>
```

- [ ] **Step 25.2: Update the play component spec**

Add to `spec/components/play/scenes/play_component_spec.rb`:

```ruby
it "renders the narration form" do
  scene = create(:scene)
  rendered = render_inline(described_class.new(scene: scene))
  expect(rendered.css("[data-controller='narration-form']")).to be_present
end

it "wraps the log in a scene-log-scroll Stimulus container" do
  scene = create(:scene)
  rendered = render_inline(described_class.new(scene: scene))
  expect(rendered.css("[data-controller='scene-log-scroll']")).to be_present
end
```

- [ ] **Step 25.3: Run and confirm pass**

```
bundle exec rspec spec/components/play/scenes/play_component_spec.rb
```

- [ ] **Step 25.4: Commit**

```
git add app/components/play/scenes/play_component.html.erb spec/components/play/scenes/play_component_spec.rb
git commit -m "Render narration form + scroll wrapper in Play::Scenes::PlayComponent (Phase 8.25)"
```

---

## Task 26: Stimulus controllers — narration_form + scene_log_scroll

**Files:**
- Create: `app/javascript/controllers/narration_form_controller.js`
- Create: `app/javascript/controllers/scene_log_scroll_controller.js`
- Modify: `app/javascript/controllers/index.js` (or `application.js`, whichever the project uses to register controllers — verify with `ls app/javascript/controllers/`)

- [ ] **Step 26.1: Identify the controller registration file**

```
ls app/javascript/controllers/
cat app/javascript/controllers/index.js 2>/dev/null || cat app/javascript/application.js
```

The output reveals where to register new controllers. Phase 7's `dice_form_controller.js` is registered in the same place.

- [ ] **Step 26.2: Implement `narration_form_controller.js`**

Create `app/javascript/controllers/narration_form_controller.js`:

```javascript
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
```

- [ ] **Step 26.3: Implement `scene_log_scroll_controller.js`**

Create `app/javascript/controllers/scene_log_scroll_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="scene-log-scroll"
//
// Auto-scrolls the page to the bottom when new content is appended to the
// log container, IF the user was already near the bottom. Does NOT yank
// the scroll if they've scrolled up to read older content.
export default class extends Controller {
  static threshold = 120  // pixels from bottom to count as "near bottom"

  connect() {
    this.wasNearBottom = true
    this.scrollListener = () => this.recordScrollPosition()
    this.observer = new MutationObserver(() => this.maybeScroll())

    window.addEventListener("scroll", this.scrollListener, { passive: true })
    this.observer.observe(this.element, { childList: true, subtree: true })
  }

  disconnect() {
    window.removeEventListener("scroll", this.scrollListener)
    this.observer.disconnect()
  }

  recordScrollPosition() {
    const distanceFromBottom = document.documentElement.scrollHeight
                             - window.innerHeight
                             - window.scrollY
    this.wasNearBottom = distanceFromBottom < this.constructor.threshold
  }

  maybeScroll() {
    if (this.wasNearBottom) {
      window.scrollTo({ top: document.documentElement.scrollHeight, behavior: "smooth" })
    }
  }
}
```

- [ ] **Step 26.4: Register both controllers**

Edit the controller registration file from step 26.1. Add (preserving existing registrations):

```javascript
import NarrationFormController from "./narration_form_controller"
import SceneLogScrollController from "./scene_log_scroll_controller"

application.register("narration-form", NarrationFormController)
application.register("scene-log-scroll", SceneLogScrollController)
```

(If the project uses `eagerLoadControllersFrom`, the `import` lines and explicit `register` calls may not be needed — the convention is enough. Confirm by reading the existing file.)

- [ ] **Step 26.5: Build the JS bundle**

```
bun install
bin/dev   # one-shot to confirm the bundler completes; Ctrl+C
```

(Or run `bun build` per the project's `package.json` scripts. Confirm no compile errors.)

- [ ] **Step 26.6: Commit**

```
git add app/javascript/controllers/narration_form_controller.js app/javascript/controllers/scene_log_scroll_controller.js app/javascript/controllers/index.js
git commit -m "Add narration-form and scene-log-scroll Stimulus controllers (Phase 8.26)"
```

---

## Task 27: `Admin::SceneClosuresController` + close-button component + route

**Files:**
- Modify: `config/routes/admin.rb`
- Create: `app/controllers/admin/scene_closures_controller.rb`
- Create: `app/components/admin/scenes/close_button_component.rb`
- Create: `app/components/admin/scenes/close_button_component.html.erb`
- Create: `spec/requests/admin/scene_closures_spec.rb`
- Create: `spec/components/admin/scenes/close_button_component_spec.rb`

- [ ] **Step 27.1: Add the nested route**

Edit `config/routes/admin.rb`. In the `resources :scenes` block, add:

```ruby
resource :closure, only: [:create], controller: "scene_closures"
```

So the block reads:

```ruby
resources :scenes do
  member do
    post :move_up
    post :move_down
  end
  resource :closure, only: [:create], controller: "scene_closures"
end
```

- [ ] **Step 27.2: Sanity-check the route**

```
bin/rails routes -g closure
```

Expected: a `POST /campaigns/:campaign_id/scenes/:scene_id/closure` named `admin_campaign_scene_closure`.

- [ ] **Step 27.3: Implement the controller**

Create `app/controllers/admin/scene_closures_controller.rb`:

```ruby
module Admin
  class SceneClosuresController < Admin::ApplicationController
    before_action :load_scene

    def create
      if @scene.closed?
        redirect_to admin_campaign_path(@scene.campaign), alert: "Scene already closed."
        return
      end

      @scene.update!(closed_at: Time.current)
      SceneAuditJob.perform_later(@scene.id)
      redirect_to admin_campaign_path(@scene.campaign),
                  notice: "Scene closed; audit running."
    end

    private

    def load_scene
      @scene = current_user.campaigns.find(params[:campaign_id]).scenes.find(params[:scene_id])
    end
  end
end
```

- [ ] **Step 27.4: Implement the component**

Create `app/components/admin/scenes/close_button_component.rb`:

```ruby
module Admin
  module Scenes
    class CloseButtonComponent < ViewComponent::Base
      def initialize(scene:)
        @scene = scene
      end

      attr_reader :scene

      def disabled?
        scene.closed?
      end

      def label
        disabled? ? "Closed" : "End scene"
      end

      def submit_path
        helpers.admin_campaign_scene_closure_path(scene.campaign, scene)
      end
    end
  end
end
```

Create `app/components/admin/scenes/close_button_component.html.erb`:

```erb
<% if disabled? %>
  <span class="inline-block rounded bg-slate-700 px-3 py-1 text-xs uppercase tracking-widest text-slate-400">
    <%= label %>
  </span>
<% else %>
  <%= button_to label, submit_path, method: :post,
                data: { turbo_confirm: "Close this scene and run the audit?" },
                class: "rounded bg-amber-700 px-3 py-1 text-xs uppercase tracking-widest text-amber-50 hover:bg-amber-600" %>
<% end %>
```

- [ ] **Step 27.5: Write the request spec**

Create `spec/requests/admin/scene_closures_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Admin::SceneClosures", type: :request do
  let(:user)     { create(:user) }
  let(:campaign) { create(:campaign, user: user) }
  let(:scene)    { create(:scene, campaign: campaign) }

  before { sign_in user }

  describe "POST /campaigns/:cid/scenes/:sid/closure" do
    let(:path) { admin_campaign_scene_closure_path(campaign, scene, subdomain: "admin") }

    it "sets closed_at and enqueues SceneAuditJob" do
      expect {
        post path
      }.to change { scene.reload.closed_at }.from(nil)
       .and have_enqueued_job(SceneAuditJob).with(scene.id)

      expect(response).to redirect_to(admin_campaign_path(campaign, subdomain: "admin"))
      follow_redirect!
      expect(flash[:notice]).to include("Scene closed")
    end

    it "rejects already-closed scenes with an alert" do
      scene.update!(closed_at: Time.current)
      expect {
        post path
      }.not_to have_enqueued_job(SceneAuditJob)
      follow_redirect!
      expect(flash[:alert]).to include("already closed")
    end

    it "404s on cross-user access" do
      other = create(:scene, campaign: create(:campaign))
      expect {
        post admin_campaign_scene_closure_path(other.campaign, other, subdomain: "admin")
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
```

(If existing admin specs use a different subdomain helper convention, follow that pattern. The Phase 7 admin specs in `spec/requests/admin/` set the subdomain via `host! "admin.example.com"` or via the route helper `subdomain:` param. Use whichever the existing project uses; check `spec/requests/admin/campaigns_spec.rb`.)

- [ ] **Step 27.6: Write the component spec**

Create `spec/components/admin/scenes/close_button_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Admin::Scenes::CloseButtonComponent, type: :component do
  let(:scene) { create(:scene) }

  it "renders a clickable End scene button when scene is open" do
    rendered = render_inline(described_class.new(scene: scene))
    expect(rendered.css("button[type='submit']").text).to include("End scene")
  end

  it "renders a disabled Closed label when scene is closed" do
    scene.update!(closed_at: Time.current)
    rendered = render_inline(described_class.new(scene: scene))
    expect(rendered.css("button")).to be_empty
    expect(rendered.text).to include("Closed")
  end
end
```

- [ ] **Step 27.7: Run and confirm pass**

```
bundle exec rspec spec/requests/admin/scene_closures_spec.rb spec/components/admin/scenes/close_button_component_spec.rb
```

- [ ] **Step 27.8: Commit**

```
git add config/routes/admin.rb app/controllers/admin/scene_closures_controller.rb app/components/admin/scenes/close_button_component.rb app/components/admin/scenes/close_button_component.html.erb spec/requests/admin/scene_closures_spec.rb spec/components/admin/scenes/close_button_component_spec.rb
git commit -m "Add Admin::SceneClosuresController + CloseButtonComponent (Phase 8.27)"
```

---

## Task 28: Render close button + audit link in `Admin::Scenes::RowComponent`

**Files:**
- Modify: `app/components/admin/scenes/row_component.rb`
- Modify: `app/components/admin/scenes/row_component.html.erb`
- Modify: `spec/components/admin/scenes/row_component_spec.rb`

- [ ] **Step 28.1: Update the row component**

Edit `app/components/admin/scenes/row_component.html.erb`. Find the buttons region (where edit/delete/move buttons render) and add the close button + audit link. Preserve existing buttons; the new affordances go in their own group:

```erb
<%= render Admin::Scenes::CloseButtonComponent.new(scene: scene) %>

<% if scene.closed? %>
  <%= link_to "View audit",
              admin_campaign_scene_audit_path(scene.campaign, scene),
              class: "rounded bg-slate-700 px-3 py-1 text-xs uppercase tracking-widest text-slate-300 hover:text-slate-100" %>
<% end %>
```

(The exact placement depends on the existing `row_component.html.erb` layout. Insert in the same `flex` row as the existing edit/delete buttons.)

- [ ] **Step 28.2: Update the spec**

Add to `spec/components/admin/scenes/row_component_spec.rb`:

```ruby
describe "scene closure UI" do
  let(:campaign) { create(:campaign) }

  it "renders the End scene button when scene is open" do
    scene = create(:scene, campaign: campaign)
    rendered = render_inline(described_class.new(scene: scene))
    expect(rendered.text).to include("End scene")
    expect(rendered.text).not_to include("View audit")
  end

  it "renders the View audit link when scene is closed" do
    scene = create(:scene, campaign: campaign, closed_at: Time.current)
    rendered = render_inline(described_class.new(scene: scene))
    expect(rendered.text).to include("Closed")
    expect(rendered.text).to include("View audit")
  end
end
```

- [ ] **Step 28.3: Run and confirm pass**

```
bundle exec rspec spec/components/admin/scenes/row_component_spec.rb
```

(If the row component uses `helpers.admin_campaign_scene_audit_path` and the route doesn't exist yet, the spec will fail. Wire the route stub now: jump to Task 29.1, define the route, then return.)

- [ ] **Step 28.4: Commit**

```
git add app/components/admin/scenes/row_component.html.erb app/components/admin/scenes/row_component.rb spec/components/admin/scenes/row_component_spec.rb
git commit -m "Render End scene + View audit affordances in Admin::Scenes::RowComponent (Phase 8.28)"
```

---

## Task 29: `Admin::SceneAuditsController` + show component + route

**Files:**
- Modify: `config/routes/admin.rb`
- Create: `app/controllers/admin/scene_audits_controller.rb`
- Create: `app/components/admin/scene_audits/show_component.rb`
- Create: `app/components/admin/scene_audits/show_component.html.erb`
- Create: `spec/requests/admin/scene_audits_spec.rb`
- Create: `spec/components/admin/scene_audits/show_component_spec.rb`

- [ ] **Step 29.1: Add the nested route**

Edit `config/routes/admin.rb`. In the `resources :scenes` block, add the audit resource alongside the closure:

```ruby
resources :scenes do
  member do
    post :move_up
    post :move_down
  end
  resource :closure, only: [:create], controller: "scene_closures"
  resource :audit,   only: [:show],   controller: "scene_audits"
end
```

- [ ] **Step 29.2: Sanity-check the route**

```
bin/rails routes -g audit
```

Expected: `GET /campaigns/:campaign_id/scenes/:scene_id/audit` named `admin_campaign_scene_audit`.

- [ ] **Step 29.3: Implement the controller**

Create `app/controllers/admin/scene_audits_controller.rb`:

```ruby
module Admin
  class SceneAuditsController < Admin::ApplicationController
    before_action :load_scene

    def show
      @audit = @scene.audit
      render Admin::SceneAudits::ShowComponent.new(scene: @scene, audit: @audit)
    end

    private

    def load_scene
      @scene = current_user.campaigns.find(params[:campaign_id]).scenes.find(params[:scene_id])
    end
  end
end
```

- [ ] **Step 29.4: Implement the component**

Create `app/components/admin/scene_audits/show_component.rb`:

```ruby
module Admin
  module SceneAudits
    class ShowComponent < ViewComponent::Base
      def initialize(scene:, audit:)
        @scene = scene
        @audit = audit
      end

      attr_reader :scene, :audit

      def running?
        audit.nil?
      end

      def verdict_label
        audit&.verdict&.upcase
      end

      def verdict_classes
        case audit&.verdict
        when "pass"     then "bg-emerald-900/40 border-emerald-700 text-emerald-200"
        when "concerns" then "bg-amber-900/40 border-amber-700 text-amber-200"
        when "fail"     then "bg-rose-900/40 border-rose-700 text-rose-200"
        else                 "bg-slate-800 border-slate-700 text-slate-300"
        end
      end

      def criteria
        audit&.result&.fetch("criteria", []) || []
      end

      def summary
        audit&.result&.fetch("summary", "")
      end
    end
  end
end
```

Create `app/components/admin/scene_audits/show_component.html.erb`:

```erb
<div class="mx-auto max-w-3xl px-4 py-8">
  <div class="mb-6">
    <%= link_to "← Back to #{scene.campaign.name}",
                admin_campaign_path(scene.campaign),
                class: "text-xs uppercase tracking-widest text-slate-500 hover:text-slate-300" %>
  </div>

  <h1 class="text-2xl font-bold tracking-tight"><%= scene.title %> · audit</h1>

  <% if running? %>
    <div class="mt-6 rounded border border-slate-700 bg-slate-800 p-4 text-slate-300">
      Audit running… refresh in a few seconds.
    </div>
  <% else %>
    <div class="mt-6 rounded border <%= verdict_classes %> p-4">
      <p class="text-xs uppercase tracking-widest">Verdict</p>
      <p class="mt-1 text-3xl font-bold"><%= verdict_label %></p>
    </div>

    <% if criteria.any? %>
      <h2 class="mt-8 text-sm uppercase tracking-widest text-slate-500">Criteria</h2>
      <ul class="mt-2 divide-y divide-slate-800 rounded border border-slate-800">
        <% criteria.each do |criterion| %>
          <li class="px-4 py-3">
            <p class="text-sm font-medium text-slate-200"><%= criterion["name"] %></p>
            <p class="text-xs uppercase tracking-widest text-slate-500"><%= criterion["status"] %></p>
            <% if criterion["note"].present? %>
              <p class="mt-1 text-sm text-slate-300"><%= criterion["note"] %></p>
            <% end %>
          </li>
        <% end %>
      </ul>
    <% end %>

    <% if summary.present? %>
      <h2 class="mt-8 text-sm uppercase tracking-widest text-slate-500">Summary</h2>
      <p class="mt-2 text-sm text-slate-200"><%= summary %></p>
    <% end %>

    <% if audit.result["error"].present? %>
      <div class="mt-8 rounded border border-rose-700 bg-rose-900/30 p-4">
        <p class="text-sm font-medium text-rose-300">Audit error: <%= audit.result["error"] %></p>
        <% if audit.result["raw"].present? %>
          <details class="mt-2">
            <summary class="cursor-pointer text-xs text-rose-400">Raw model response</summary>
            <pre class="mt-2 whitespace-pre-wrap text-xs text-rose-200"><%= audit.result["raw"] %></pre>
          </details>
        <% end %>
      </div>
    <% end %>
  <% end %>
</div>
```

- [ ] **Step 29.5: Write the request spec**

Create `spec/requests/admin/scene_audits_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Admin::SceneAudits", type: :request do
  let(:user)     { create(:user) }
  let(:campaign) { create(:campaign, user: user) }
  let(:scene)    { create(:scene, campaign: campaign) }

  before { sign_in user }

  describe "GET /campaigns/:cid/scenes/:sid/audit" do
    let(:path) { admin_campaign_scene_audit_path(campaign, scene, subdomain: "admin") }

    it "renders the running placeholder when no audit exists" do
      get path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Audit running")
    end

    it "renders the audit when present" do
      create(:scene_audit, scene: scene)
      get path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("PASS")
    end

    it "404s on cross-user access" do
      other = create(:scene, campaign: create(:campaign))
      expect {
        get admin_campaign_scene_audit_path(other.campaign, other, subdomain: "admin")
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
```

- [ ] **Step 29.6: Write the component spec**

Create `spec/components/admin/scene_audits/show_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Admin::SceneAudits::ShowComponent, type: :component do
  let(:scene) { create(:scene) }

  it "renders the running placeholder when audit is nil" do
    rendered = render_inline(described_class.new(scene: scene, audit: nil))
    expect(rendered.text).to include("Audit running")
  end

  it "renders verdict, criteria, summary when audit is present" do
    audit = create(:scene_audit, scene: scene)
    rendered = render_inline(described_class.new(scene: scene, audit: audit))
    expect(rendered.text).to include("PASS")
    expect(rendered.text).to include("player_agency")
    expect(rendered.text).to include("Looks good.")
  end

  it "renders an error block when result has an error key" do
    audit = create(:scene_audit, :failed, scene: scene,
                   result: { "error" => "audit_parse_failed", "raw" => "garbage" })
    rendered = render_inline(described_class.new(scene: scene, audit: audit))
    expect(rendered.text).to include("Audit error: audit_parse_failed")
    expect(rendered.text).to include("garbage")
  end
end
```

- [ ] **Step 29.7: Run and confirm pass**

```
bundle exec rspec spec/requests/admin/scene_audits_spec.rb spec/components/admin/scene_audits/show_component_spec.rb spec/components/admin/scenes/row_component_spec.rb
```

- [ ] **Step 29.8: Commit**

```
git add config/routes/admin.rb app/controllers/admin/scene_audits_controller.rb app/components/admin/scene_audits/show_component.rb app/components/admin/scene_audits/show_component.html.erb spec/requests/admin/scene_audits_spec.rb spec/components/admin/scene_audits/show_component_spec.rb
git commit -m "Add Admin::SceneAuditsController + ShowComponent (Phase 8.29)"
```

---

## Task 30: System spec — Phase 8 streaming round trip

**Files:**
- Create: `spec/system/phase_8_narrator_streaming_spec.rb`

- [ ] **Step 30.1: Write the system spec**

Create `spec/system/phase_8_narrator_streaming_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Phase 8 narrator streaming", type: :system, js: true do
  let(:user) { create(:user) }
  let!(:campaign) { create(:campaign, user: user, name: "Test Run", description: "A short test campaign.") }
  let!(:scene) { create(:scene, campaign: campaign, title: "The Tavern", summary: "A noisy hall.") }

  before do
    allow(Rails.application.credentials).to receive(:dig).with(:anthropic, :api_key).and_return("sk-test")
    Llm::Providers::Anthropic.reset_client!
    stub_anthropic_streaming(text_chunks: ["The bartender ", "looks up. ", "He waves you over."],
                             input_tokens: 50, output_tokens: 12)

    sign_in_via_form(user)
  end

  it "submits a player action, streams the narration into the log, and finalizes" do
    visit play_campaign_scene_url(campaign, scene, host: "localhost")

    fill_in "narration[text]", with: "I greet the bartender."
    click_button "Narrate"

    expect(page).to have_text("I greet the bartender.")
    perform_enqueued_jobs

    expect(page).to have_text("The bartender looks up. He waves you over.")
    expect(page).not_to have_css("[data-narration-status='streaming']")
  end

  def sign_in_via_form(user)
    visit new_user_session_url(host: "localhost")
    fill_in "user[email]",    with: user.email
    fill_in "user[password]", with: user.password
    click_button "Log in"
  end
end
```

(Helper signature: `sign_in_via_form` does the Devise login flow through the actual form. Phase 7's system spec used the same approach; reuse the existing helper if present.)

- [ ] **Step 30.2: Run the system spec**

```
bundle exec rspec spec/system/phase_8_narrator_streaming_spec.rb
```

Expected: green. The job runs synchronously via `perform_enqueued_jobs`; the WebMock stub returns the SSE body; the page assertion waits for the broadcasted Turbo Stream replace to land.

If the test flakes due to ActionCable timing, add an explicit `expect(page).to have_text("The bartender", wait: 10)` to give the broadcast time to land.

- [ ] **Step 30.3: Commit**

```
git add spec/system/phase_8_narrator_streaming_spec.rb
git commit -m "Add Phase 8 system spec — streaming round trip (Phase 8.30)"
```

---

## Task 31: Lookbook previews

**Files:**
- Create: `spec/components/previews/play/narration/form_component_preview.rb`
- Create: `spec/components/previews/play/events/player_action_component_preview.rb`
- Modify: `spec/components/previews/play/events/narration_component_preview.rb` (extend with streaming/errored)
- Create: `spec/components/previews/admin/scenes/close_button_component_preview.rb`
- Create: `spec/components/previews/admin/scene_audits/show_component_preview.rb`

- [ ] **Step 31.1: Narration form preview**

Create `spec/components/previews/play/narration/form_component_preview.rb`:

```ruby
module Play
  module Narration
    class FormComponentPreview < Lookbook::Preview
      def default
        scene = Scene.new(id: 1, title: "T", summary: "S", campaign: Campaign.new(id: 1, name: "Demo"))
        render(Play::Narration::FormComponent.new(scene: scene))
      end

      def with_sticky_text
        scene = Scene.new(id: 1, title: "T", summary: "S", campaign: Campaign.new(id: 1, name: "Demo"))
        render(Play::Narration::FormComponent.new(scene: scene, text: "I open the door.", error: nil))
      end

      def with_error
        scene = Scene.new(id: 1, title: "T", summary: "S", campaign: Campaign.new(id: 1, name: "Demo"))
        render(Play::Narration::FormComponent.new(scene: scene, text: " ", error: "type something to do"))
      end
    end
  end
end
```

- [ ] **Step 31.2: Player action preview**

Create `spec/components/previews/play/events/player_action_component_preview.rb`:

```ruby
module Play
  module Events
    class PlayerActionComponentPreview < Lookbook::Preview
      def default
        event = Event.new(id: 1, kind: "player_action",
                          payload: { "text" => "I push the door open." },
                          occurred_at: 30.seconds.ago)
        render(Play::Events::PlayerActionComponent.new(event: event))
      end

      def long_text
        event = Event.new(id: 2, kind: "player_action",
                          payload: { "text" => "I take a slow look around the entire room — the bar, the rafters, the booths in the back, anyone who might be watching. I'm trying to read the mood." },
                          occurred_at: 2.minutes.ago)
        render(Play::Events::PlayerActionComponent.new(event: event))
      end
    end
  end
end
```

- [ ] **Step 31.3: Extend narration preview**

Edit `spec/components/previews/play/events/narration_component_preview.rb`. Add the streaming and errored examples (preserve existing examples):

```ruby
def streaming
  event = Event.new(id: 10, kind: "narration",
                    payload: { "text" => "The bartender looks up", "status" => "streaming" },
                    occurred_at: 5.seconds.ago)
  render(Play::Events::NarrationComponent.new(event: event))
end

def complete
  event = Event.new(id: 11, kind: "narration",
                    payload: { "text" => "The bartender looks up. He waves you over.", "status" => "complete" },
                    occurred_at: 1.minute.ago)
  render(Play::Events::NarrationComponent.new(event: event))
end

def errored
  event = Event.new(id: 12, kind: "narration",
                    payload: { "text" => "The bartender", "status" => "errored",
                               "error_message" => "rate limit exceeded" },
                    occurred_at: 10.seconds.ago)
  render(Play::Events::NarrationComponent.new(event: event))
end
```

- [ ] **Step 31.4: Close-button preview**

Create `spec/components/previews/admin/scenes/close_button_component_preview.rb`:

```ruby
module Admin
  module Scenes
    class CloseButtonComponentPreview < Lookbook::Preview
      def available
        scene = Scene.new(id: 1, title: "T", campaign: Campaign.new(id: 1))
        render(Admin::Scenes::CloseButtonComponent.new(scene: scene))
      end

      def disabled_already_closed
        scene = Scene.new(id: 1, title: "T", closed_at: Time.current,
                          campaign: Campaign.new(id: 1))
        render(Admin::Scenes::CloseButtonComponent.new(scene: scene))
      end
    end
  end
end
```

- [ ] **Step 31.5: Audit show preview**

Create `spec/components/previews/admin/scene_audits/show_component_preview.rb`:

```ruby
module Admin
  module SceneAudits
    class ShowComponentPreview < Lookbook::Preview
      def pass
        scene = Scene.new(id: 1, title: "The Tavern", campaign: Campaign.new(id: 1, name: "Demo"))
        audit = SceneAudit.new(scene: scene, verdict: "pass",
                               result: pass_result)
        render(Admin::SceneAudits::ShowComponent.new(scene: scene, audit: audit))
      end

      def concerns
        scene = Scene.new(id: 1, title: "The Tavern", campaign: Campaign.new(id: 1, name: "Demo"))
        audit = SceneAudit.new(scene: scene, verdict: "concerns",
                               result: concerns_result)
        render(Admin::SceneAudits::ShowComponent.new(scene: scene, audit: audit))
      end

      def failed
        scene = Scene.new(id: 1, title: "The Tavern", campaign: Campaign.new(id: 1, name: "Demo"))
        audit = SceneAudit.new(scene: scene, verdict: "fail",
                               result: { "error" => "audit_parse_failed", "raw" => "definitely not json" })
        render(Admin::SceneAudits::ShowComponent.new(scene: scene, audit: audit))
      end

      def running
        scene = Scene.new(id: 1, title: "The Tavern", campaign: Campaign.new(id: 1, name: "Demo"))
        render(Admin::SceneAudits::ShowComponent.new(scene: scene, audit: nil))
      end

      private

      def pass_result
        {
          "verdict" => "pass",
          "criteria" => [
            { "name" => "player_agency",            "status" => "pass", "note" => "Players were given clear choices." },
            { "name" => "follow_through",           "status" => "pass", "note" => "Player declarations were honored." },
            { "name" => "over_narration_of_intent", "status" => "pass", "note" => "Narrator stayed external." },
            { "name" => "mechanical_handoff",       "status" => "pass", "note" => "Dice prompted at the right beats." }
          ],
          "summary" => "A clean turn. Narrator framed choices and let the player drive."
        }
      end

      def concerns_result
        {
          "verdict" => "concerns",
          "criteria" => [
            { "name" => "player_agency",            "status" => "pass",     "note" => "Choices were offered." },
            { "name" => "follow_through",           "status" => "concerns", "note" => "Two declarations went unaddressed." },
            { "name" => "over_narration_of_intent", "status" => "pass",     "note" => "—" },
            { "name" => "mechanical_handoff",       "status" => "pass",     "note" => "—" }
          ],
          "summary" => "Mostly clean. Watch for dropped player declarations."
        }
      end
    end
  end
end
```

- [ ] **Step 31.6: Sanity-check that previews load**

```
bin/rails server -p 3000 &
sleep 5
curl -s http://localhost:3000/lookbook/inspect/play/narration/form_component | head -10
kill %1
```

Expected: HTML output with the form rendered. (The exact path depends on Lookbook's route prefix.)

- [ ] **Step 31.7: Commit**

```
git add spec/components/previews/play/narration/form_component_preview.rb spec/components/previews/play/events/player_action_component_preview.rb spec/components/previews/play/events/narration_component_preview.rb spec/components/previews/admin/scenes/close_button_component_preview.rb spec/components/previews/admin/scene_audits/show_component_preview.rb
git commit -m "Add Phase 8 Lookbook previews (Phase 8.31)"
```

---

## Task 32: Final polish — RuboCop, erb_lint, annotaterb, full RSpec, Brakeman

**Files:**
- Various (whatever the linters complain about).

- [ ] **Step 32.1: Run RuboCop and fix violations**

```
bundle exec rubocop --autocorrect-all app spec
```

Fix any remaining violations manually.

- [ ] **Step 32.2: Run erb_lint and fix violations**

```
bundle exec erb_lint --lint-all
```

Fix violations manually.

- [ ] **Step 32.3: Refresh annotations**

```
bundle exec annotaterb models
bundle exec annotaterb factories
```

- [ ] **Step 32.4: Run the full RSpec suite**

```
bundle exec rspec
```

Expected: all green. If any spec fails, debug and fix in place.

- [ ] **Step 32.5: Run Brakeman**

```
bundle exec brakeman --no-pager
```

Expected: no new warnings vs the prior baseline. If any new warnings appear, address them or document a `brakeman.ignore` entry with rationale.

- [ ] **Step 32.6: Commit any fixes**

```
git add -A
git commit -m "Lint, annotation, and Brakeman polish for Phase 8 (Phase 8.32)"
```

- [ ] **Step 32.7: Push and confirm CI green**

```
git push origin main
```

Watch CI; if anything fails, fix in a follow-up commit.

---

## Self-review against the spec

Coverage check vs `docs/superpowers/specs/2026-05-14-v2-phase-8-narrator-streaming-design.md`:

- **Narrator::PromptBuilder + asymmetry tests** → Tasks 14, 15.
- **Llm::Providers::Anthropic#call_streaming + first-class cache_breakpoints** → Tasks 9, 10, 11.
- **Llm::Call.execute_streaming** → Task 12.
- **`:bookkeeper_audit` purpose** → Task 13.
- **`player_action` event kind** → Task 1.
- **`closed_at` on scenes** → Task 2.
- **`scene_audits` table + SceneAudit model + Campaign reach** → Tasks 3, 4.
- **Player::CampaignViewModel / SceneViewModel / EventViewModel** → Tasks 5, 6, 7.
- **Narrator::SceneAuditViewModel / EventViewModel** → Task 8.
- **Narrator::SystemPrompt + AuditSystemPrompt + AuditPromptBuilder** → Tasks 14, 16, 17.
- **NarrationJob with chunk batching + per-(scene, user) Turbo broadcasts** → Task 19.
- **SceneAuditJob with structured-output parsing + idempotency** → Task 20.
- **Play::Narration::FormComponent + dom_id targeting** → Task 21.
- **Play::Events::PlayerActionComponent + REGISTRY update** → Task 22.
- **Play::Events::NarrationComponent status branches** → Task 23.
- **Play::NarrationsController + nested route + transactional event creation** → Task 24.
- **Render form + scene-log-scroll wrapper in PlayComponent** → Task 25.
- **narration_form + scene_log_scroll Stimulus controllers** → Task 26.
- **Admin::SceneClosuresController + CloseButtonComponent + route** → Task 27.
- **Update Admin::Scenes::RowComponent for close + audit affordances** → Task 28.
- **Admin::SceneAuditsController + ShowComponent + route** → Task 29.
- **Phase 8 system spec (streaming round-trip)** → Task 30.
- **Lookbook previews for new + extended components** → Task 31.
- **anthropic_streaming + turbo_streams test helpers** → Tasks 11 (anthropic_streaming), 18 (turbo_streams).
- **README "Narration loop" section** → not in the plan as a separate task; merge into Task 32 polish or skip if README has no Operations section to extend (verify).
- **No new ENV vars** → confirmed; spec acknowledges this.

Out-of-scope items from the spec are correctly absent from the plan: no retry button, no audit live-update, no cost dashboard, no rate limits.

---

**Plan complete and saved to** `docs/superpowers/plans/2026-05-14-v2-phase-8-narrator-streaming.md`.

Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
