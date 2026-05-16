# Phase 9.1 — DM turn discipline implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement Phase 9.1 — encode D&D turn discipline structurally so the narrator stops at handoffs by construction, not by hope. Closes #12, #13, #14, #15, #19, #25.

**Architecture:** Event-sourced turn state machine derived from a typed event log; conversation-shaped LLM history (per-turn user message + per-resolution assistant message); chat-based play surface with chip-based dice requests that pause the narrator mid-flight. New `PlayerCharacter` (PC/companion) and `SceneSecret` tables provide the asymmetry-correct foundation.

**Tech Stack:** Rails 8.1, RSpec, ViewComponent, Stimulus + Turbo Streams over Solid Cable, Anthropic Claude SDK, commonmarker (new), Selenium headless Chrome for system specs.

**Spec:** [docs/superpowers/specs/2026-05-16-v2-phase-9-1-dm-turn-discipline-design.md](../specs/2026-05-16-v2-phase-9-1-dm-turn-discipline-design.md)

---

## File structure

### New files

**Models & migrations**
- `db/migrate/<ts>_create_player_characters.rb`
- `db/migrate/<ts>_create_scene_secrets.rb`
- `db/migrate/<ts>_add_main_character_to_campaigns.rb`
- `db/migrate/<ts>_add_pc_and_turn_to_events.rb`
- `db/migrate/<ts>_clean_play_events_for_phase_9_1.rb` — destructive data migration (clean slate per spec)
- `app/models/player_character.rb`
- `app/models/scene_secret.rb`

**View models**
- `app/view_models/player/player_character_view_model.rb` — player-safe (no `notes`)
- `app/view_models/narrator/player_character_view_model.rb` — DM-side (includes `notes`)
- `app/view_models/narrator/scene_secret_view_model.rb` — DM-side only
- `app/view_models/narrator/campaign_view_model.rb` — DM-side (exposes faction/npc secrets via associations)
- `app/view_models/narrator/scene_view_model.rb` — DM-side (exposes scene_secrets)
- `app/view_models/narrator/faction_view_model.rb` — DM-side wrapper around Faction (exposes its secrets via FactionSecretViewModel)
- `app/view_models/narrator/npc_view_model.rb` — DM-side wrapper around Npc (exposes its secrets via NpcSecretViewModel)
- `app/view_models/player/scene_state_view_model.rb` — derived turn state

**LLM / Narrator**
- `app/lib/narrator/collection_prompt.rb` — templated agent prompts
- `app/lib/narrator/declaration_parser.rb` — attribution parser
- `app/lib/narrator/declaration_parser/success.rb` — result type
- `app/lib/narrator/declaration_parser/failure.rb` — result type
- `app/lib/narrator/declaration_parser/dice_roll.rb` — result type
- `app/lib/narrator/chip_parser.rb` — parses `[[…]]` dice chips out of narration text

**Controllers (admin)**
- `app/controllers/admin/player_characters_controller.rb`
- `app/controllers/admin/scene_secrets_controller.rb`

**Controllers (play)**
- `app/controllers/play/pc_declarations_controller.rb`

**Components (admin)**
- `app/components/admin/player_characters/index_component.{rb,html.erb}`
- `app/components/admin/player_characters/show_component.{rb,html.erb}`
- `app/components/admin/player_characters/form_component.{rb,html.erb}`
- `app/components/admin/player_characters/row_component.{rb,html.erb}`
- `app/components/admin/scene_secrets/index_component.{rb,html.erb}`
- `app/components/admin/scene_secrets/show_component.{rb,html.erb}`
- `app/components/admin/scene_secrets/form_component.{rb,html.erb}`
- `app/components/admin/scene_secrets/row_component.{rb,html.erb}`

**Components (play)**
- `app/components/play/events/pc_declaration_component.{rb,html.erb}`
- `app/components/play/events/gm_collection_prompt_component.{rb,html.erb}`
- `app/components/play/state_indicator_component.{rb,html.erb}`
- `app/components/play/roster/sidebar_component.{rb,html.erb}`
- `app/components/play/composer_component.{rb,html.erb}`

**Stimulus**
- `app/javascript/controllers/chat_composer_controller.js`
- `app/javascript/controllers/dice_chip_controller.js`

**Factories**
- `spec/factories/player_characters.rb`
- `spec/factories/scene_secrets.rb`

### Modified files

- `app/models/event.rb` — KINDS enum: add `pc_declaration`, `gm_collection_prompt`; remove `player_action`, `oracle_query` (or whatever name exists)
- `app/models/campaign.rb` — `belongs_to :main_character, class_name: "PlayerCharacter", optional: true`; `has_many :player_characters`
- `app/models/scene.rb` — `has_many :scene_secrets, dependent: :destroy`
- `app/lib/narrator/system_prompt.rb` — replace TEXT with discipline prompt template
- `app/lib/narrator/prompt_builder.rb` — full rewrite (conversation messages + Narrator VMs)
- `app/lib/narrator/prompt.rb` — accept `stop_sequences` field
- `app/lib/llm/providers/anthropic.rb` — negative cache_breakpoints (message indices) + `stop_sequences` pass-through
- `app/lib/llm/call.rb` — thread `stop_sequences` through
- `app/jobs/narration_job.rb` — trigger discriminator (framing/resolution/continuation), multi-segment narration support, stop_sequence handling
- `app/controllers/play/scenes_controller.rb` — auto-fire framing call when scene loads with zero events
- `app/controllers/play/dice_rolls_controller.rb` — enqueue continuation job after roll
- `app/components/play/events/component.rb` — register new event-kind components, remove oracle
- `app/components/play/events/narration_component.{rb,html.erb}` — render markdown + parse dice chips
- `app/components/play/scenes/play_component.{rb,html.erb}` — chat layout with composer + roster sidebar; disable scene picker
- `app/javascript/application.js` — register new Stimulus controllers
- `config/routes/admin.rb` — nest player_characters under campaigns; scene_secrets under scenes
- `config/routes/play.rb` — replace narrations + oracle_queries with pc_declarations; keep dice_rolls
- `db/seeds.rb` — extract PCs to player_characters, encounter map to scene_secrets, drop chaos_factor seed, shrink campaign.description
- `spec/asymmetry/coverage_spec.rb` — add new components/VMs to coverage walk; remove oracle entries
- `Gemfile` + `Gemfile.lock` — add `commonmarker` gem

### Removed files

- `app/controllers/play/oracle_queries_controller.rb` (or whatever the oracle controller is named)
- `app/components/play/events/oracle_query_component.{rb,html.erb}`
- `app/components/play/oracle/form_component.{rb,html.erb}` (if exists)
- `app/services/mythic/**` (if exists per reference doc)
- `app/javascript/controllers/oracle_form_controller.js` (if exists)
- Corresponding specs

---

## Verification preamble (run BEFORE Task 1)

The reference doc flagged a possible naming inconsistency: the spec calls the existing oracle event kind `oracle_consult`, but the actual `Event::KINDS` constant may list it as `oracle_query`. Verify which is correct before starting destruction tasks.

- [ ] **Step P.1: Confirm the actual oracle event kind name**

Run: `grep -n "oracle" app/models/event.rb`
Note the actual constant value (`oracle_query` or `oracle_consult`). Use this exact string throughout the plan wherever the placeholder `<oracle_kind>` appears. If it differs from the spec's `oracle_consult`, the spec wording is incidental — the code value is authoritative.

- [ ] **Step P.2: Confirm the actual oracle controller / component paths**

Run:
```bash
ls app/controllers/play/ | grep -i oracle
ls app/components/play/ | grep -i oracle -R
ls app/javascript/controllers/ | grep -i oracle
ls app/services/ | grep -i mythic
```
Note the exact paths. Use these in deletion steps below.

- [ ] **Step P.3: Confirm test database is wipeable**

Run: `bin/rails db:reset RAILS_ENV=test` — confirm it completes without errors. Test database may be re-created multiple times during plan execution.

---

## Phase 1 — Database & models foundation

### Task 1: PlayerCharacter model & migration

**Files:**
- Create: `db/migrate/<ts>_create_player_characters.rb`
- Create: `app/models/player_character.rb`
- Create: `spec/models/player_character_spec.rb`
- Create: `spec/factories/player_characters.rb`

- [ ] **Step 1: Write the failing model spec**

Create `spec/models/player_character_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe PlayerCharacter, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:campaign) }
  end

  describe "validations" do
    subject { build(:player_character) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:campaign_id).case_insensitive }
  end

  describe "role enum" do
    it "exposes pc? and companion? predicates" do
      expect(build(:player_character, role: "pc")).to be_pc
      expect(build(:player_character, role: "companion")).to be_companion
    end

    it "defaults role to pc when unset" do
      expect(PlayerCharacter.new.role).to eq("pc")
    end

    it "rejects unknown roles" do
      expect { build(:player_character, role: "boss") }.to raise_error(ArgumentError)
    end
  end

  describe "scopes" do
    let(:campaign) { create(:campaign) }
    let!(:pc)        { create(:player_character, campaign:, role: "pc",        name: "Aragorn") }
    let!(:companion) { create(:player_character, campaign:, role: "companion", name: "Caine") }

    it ".pcs returns only PCs" do
      expect(campaign.player_characters.pcs).to contain_exactly(pc)
    end

    it ".companions returns only companions" do
      expect(campaign.player_characters.companions).to contain_exactly(companion)
    end
  end
end
```

- [ ] **Step 2: Write the factory**

Create `spec/factories/player_characters.rb`:

```ruby
FactoryBot.define do
  factory :player_character do
    campaign
    sequence(:name) { |n| "Hero #{n}" }
    pronouns       { "they/them" }
    class_name     { "Fighter" }
    level          { 1 }
    role           { "pc" }
    notes          { nil }
  end
end
```

- [ ] **Step 3: Run spec to verify it fails**

Run: `bundle exec rspec spec/models/player_character_spec.rb`
Expected: FAIL with `NameError: uninitialized constant PlayerCharacter`.

- [ ] **Step 4: Generate and write the migration**

Run: `bin/rails generate migration CreatePlayerCharacters` then replace the file body with:

```ruby
class CreatePlayerCharacters < ActiveRecord::Migration[8.1]
  def change
    create_table :player_characters do |t|
      t.references :campaign, null: false, foreign_key: { on_delete: :cascade }
      t.string  :name,       null: false
      t.string  :pronouns
      t.string  :class_name
      t.integer :level
      t.string  :role,       null: false, default: "pc"
      t.text    :notes
      t.timestamps
    end

    add_index :player_characters, [ :campaign_id, :name ], unique: true,
              name: "index_player_characters_on_campaign_and_name"
  end
end
```

- [ ] **Step 5: Write the model**

Create `app/models/player_character.rb`:

```ruby
class PlayerCharacter < ApplicationRecord
  ROLES = %w[pc companion].freeze

  belongs_to :campaign

  enum :role, ROLES.index_with(&:itself)

  validates :name, presence: true,
                   uniqueness: { scope: :campaign_id, case_sensitive: false }

  scope :pcs,        -> { where(role: "pc") }
  scope :companions, -> { where(role: "companion") }
end
```

- [ ] **Step 6: Run migration and rerun spec**

Run:
```bash
bin/rails db:migrate
RAILS_ENV=test bin/rails db:migrate
bundle exec rspec spec/models/player_character_spec.rb
```
Expected: all green.

- [ ] **Step 7: Commit**

```bash
git add db/migrate/*_create_player_characters.rb db/schema.rb \
        app/models/player_character.rb \
        spec/models/player_character_spec.rb \
        spec/factories/player_characters.rb
git commit -m "Add PlayerCharacter model (pc | companion role)"
```

---

### Task 2: SceneSecret model & migration

**Files:**
- Create: `db/migrate/<ts>_create_scene_secrets.rb`
- Create: `app/models/scene_secret.rb`
- Create: `spec/models/scene_secret_spec.rb`
- Create: `spec/factories/scene_secrets.rb`
- Modify: `app/models/scene.rb` — add `has_many :scene_secrets`

- [ ] **Step 1: Write the failing model spec**

Create `spec/models/scene_secret_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe SceneSecret, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:scene) }
  end

  describe "validations" do
    subject { build(:scene_secret) }
    it { is_expected.to validate_presence_of(:label) }
    it { is_expected.to validate_presence_of(:content) }
    it { is_expected.to validate_uniqueness_of(:label).scoped_to(:scene_id).case_insensitive }
  end

  describe "cascade delete from scene" do
    it "destroys with the scene" do
      scene  = create(:scene)
      secret = create(:scene_secret, scene:)
      expect { scene.destroy }.to change { SceneSecret.where(id: secret.id).count }.from(1).to(0)
    end
  end
end
```

- [ ] **Step 2: Write the factory**

Create `spec/factories/scene_secrets.rb`:

```ruby
FactoryBot.define do
  factory :scene_secret do
    scene
    sequence(:label) { |n| "Encounter map #{n}" }
    content          { "DM-only content for this scene." }
  end
end
```

- [ ] **Step 3: Run spec to verify it fails**

Run: `bundle exec rspec spec/models/scene_secret_spec.rb`
Expected: FAIL with `NameError: uninitialized constant SceneSecret`.

- [ ] **Step 4: Generate and write the migration**

Run: `bin/rails generate migration CreateSceneSecrets` then replace body with:

```ruby
class CreateSceneSecrets < ActiveRecord::Migration[8.1]
  def change
    create_table :scene_secrets do |t|
      t.references :scene, null: false, foreign_key: { on_delete: :cascade }
      t.string :label,   null: false
      t.text   :content, null: false
      t.timestamps
    end

    add_index :scene_secrets, [ :scene_id, :label ], unique: true,
              name: "index_scene_secrets_on_scene_and_label"
  end
end
```

- [ ] **Step 5: Write the model + scene association**

Create `app/models/scene_secret.rb`:

```ruby
class SceneSecret < ApplicationRecord
  belongs_to :scene

  validates :label,   presence: true,
                      uniqueness: { scope: :scene_id, case_sensitive: false }
  validates :content, presence: true
end
```

Modify `app/models/scene.rb` to add (placement: near other `has_many` declarations):

```ruby
  has_many :scene_secrets, dependent: :destroy
```

- [ ] **Step 6: Run migration and rerun spec**

Run:
```bash
bin/rails db:migrate
RAILS_ENV=test bin/rails db:migrate
bundle exec rspec spec/models/scene_secret_spec.rb spec/models/scene_spec.rb
```
Expected: all green.

- [ ] **Step 7: Commit**

```bash
git add db/migrate/*_create_scene_secrets.rb db/schema.rb \
        app/models/scene_secret.rb app/models/scene.rb \
        spec/models/scene_secret_spec.rb \
        spec/factories/scene_secrets.rb
git commit -m "Add SceneSecret model (per-scene DM-only briefings)"
```

---

### Task 3: Campaign main_character_id + events.pc_id + events.turn_number

**Files:**
- Create: `db/migrate/<ts>_add_main_character_to_campaigns.rb`
- Create: `db/migrate/<ts>_add_pc_and_turn_to_events.rb`
- Modify: `app/models/campaign.rb` — `belongs_to :main_character, class_name: "PlayerCharacter", optional: true`; `has_many :player_characters, dependent: :destroy`
- Modify: `app/models/event.rb` — `belongs_to :pc, class_name: "PlayerCharacter", optional: true`
- Modify: `spec/models/campaign_spec.rb` — add main_character association test
- Modify: `spec/models/event_spec.rb` — add pc association + turn_number column test

- [ ] **Step 1: Write failing spec additions**

Append to `spec/models/campaign_spec.rb` inside the `describe "associations"` block (or add the block if missing):

```ruby
    it { is_expected.to have_many(:player_characters).dependent(:destroy) }
    it "optionally belongs to a main_character" do
      expect(described_class.reflect_on_association(:main_character).options[:optional]).to eq(true)
      expect(described_class.reflect_on_association(:main_character).options[:class_name]).to eq("PlayerCharacter")
    end
```

Append to `spec/models/event_spec.rb`:

```ruby
  describe "pc association" do
    it "optionally belongs to a player_character via pc_id" do
      assoc = described_class.reflect_on_association(:pc)
      expect(assoc.options[:optional]).to eq(true)
      expect(assoc.options[:class_name]).to eq("PlayerCharacter")
    end
  end

  describe "turn_number" do
    it "is nullable and accepts integers" do
      event = create(:event, turn_number: 7)
      expect(event.reload.turn_number).to eq(7)
    end
  end
```

- [ ] **Step 2: Run specs to verify failure**

Run: `bundle exec rspec spec/models/campaign_spec.rb spec/models/event_spec.rb`
Expected: FAIL — association undefined / column missing.

- [ ] **Step 3: Write the two migrations**

`db/migrate/<ts>_add_main_character_to_campaigns.rb`:

```ruby
class AddMainCharacterToCampaigns < ActiveRecord::Migration[8.1]
  def change
    add_reference :campaigns, :main_character,
                  null: true,
                  foreign_key: { to_table: :player_characters, on_delete: :nullify }
  end
end
```

`db/migrate/<ts>_add_pc_and_turn_to_events.rb`:

```ruby
class AddPcAndTurnToEvents < ActiveRecord::Migration[8.1]
  def change
    add_reference :events, :pc,
                  null: true,
                  foreign_key: { to_table: :player_characters, on_delete: :nullify }
    add_column :events, :turn_number, :integer
    add_index  :events, [ :scene_id, :turn_number ]
  end
end
```

- [ ] **Step 4: Update the models**

In `app/models/campaign.rb`, add (alongside existing `has_many`):

```ruby
  has_many :player_characters, dependent: :destroy
  belongs_to :main_character, class_name: "PlayerCharacter", optional: true
```

In `app/models/event.rb`, add (alongside existing `belongs_to :scene`):

```ruby
  belongs_to :pc, class_name: "PlayerCharacter", optional: true
```

- [ ] **Step 5: Run migrations and specs**

Run:
```bash
bin/rails db:migrate
RAILS_ENV=test bin/rails db:migrate
bundle exec rspec spec/models/campaign_spec.rb spec/models/event_spec.rb
```
Expected: all green.

- [ ] **Step 6: Commit**

```bash
git add db/migrate/*_add_main_character_to_campaigns.rb \
        db/migrate/*_add_pc_and_turn_to_events.rb \
        db/schema.rb \
        app/models/campaign.rb app/models/event.rb \
        spec/models/campaign_spec.rb spec/models/event_spec.rb
git commit -m "Add main_character_id, events.pc_id, events.turn_number"
```

---

### Task 4: Update Event KINDS enum (add new kinds, remove old)

**Files:**
- Modify: `app/models/event.rb`
- Create: `db/migrate/<ts>_clean_play_events_for_phase_9_1.rb` — destructive cleanup
- Modify: `spec/models/event_spec.rb` — update KINDS expectations

- [ ] **Step 1: Update failing spec**

Update the KINDS describe block in `spec/models/event_spec.rb` to expect the new set (use the actual `<oracle_kind>` confirmed in Step P.1):

```ruby
  describe ".kinds" do
    it "lists the Phase 9.1 event kinds" do
      expect(described_class.kinds.keys).to match_array(
        %w[narration pc_declaration gm_collection_prompt dice_roll scene_transition]
      )
    end

    it "does not include the retired Phase 8 kinds" do
      expect(described_class.kinds.keys).not_to include("player_action", "<oracle_kind>")
    end
  end
```

- [ ] **Step 2: Run spec to verify failure**

Run: `bundle exec rspec spec/models/event_spec.rb -e "kinds"`
Expected: FAIL — old kinds still present, new kinds missing.

- [ ] **Step 3: Update the KINDS constant**

In `app/models/event.rb`, replace the KINDS constant and enum:

```ruby
  KINDS = %w[narration pc_declaration gm_collection_prompt dice_roll scene_transition].freeze
  enum :kind, KINDS.index_with(&:itself)
```

- [ ] **Step 4: Write the destructive data-cleanup migration**

`db/migrate/<ts>_clean_play_events_for_phase_9_1.rb`:

```ruby
# Destructive cleanup for Phase 9.1 alpha cutover.
# Removes events of retired kinds (player_action, <oracle_kind>) so the
# updated Event.kind enum can validate. No play data is preserved — the
# user has confirmed alpha status with no in-flight sessions.
class CleanPlayEventsForPhase91 < ActiveRecord::Migration[8.1]
  def up
    execute("DELETE FROM events WHERE kind IN ('player_action', '<oracle_kind>')")
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "Phase 9.1 cleanup destroyed events of retired kinds; no rollback possible."
  end
end
```

(Substitute the verified `<oracle_kind>` string.)

- [ ] **Step 5: Run migration + specs**

Run:
```bash
bin/rails db:migrate
RAILS_ENV=test bin/rails db:migrate
bundle exec rspec spec/models/event_spec.rb
```
Expected: green.

- [ ] **Step 6: Run the full model spec suite for regression**

Run: `bundle exec rspec spec/models/`
Expected: green except any specs that explicitly reference `player_action` or the old oracle kind in their setup. If any model spec fails because of an old kind reference, update it in this commit (legitimate fix); if any non-model spec fails, note it — it'll be fixed in the relevant later task.

- [ ] **Step 7: Commit**

```bash
git add app/models/event.rb \
        db/migrate/*_clean_play_events_for_phase_9_1.rb \
        spec/models/event_spec.rb
git commit -m "Update Event.kinds: add pc_declaration, gm_collection_prompt; drop player_action and oracle"
```

---

### Task 5: Add `commonmarker` gem for markdown rendering

**Files:**
- Modify: `Gemfile`
- Modify: `Gemfile.lock`

- [ ] **Step 1: Add the gem**

In `Gemfile`, add (alphabetically near other rendering gems, or in the main block):

```ruby
gem "commonmarker", "~> 2.4"
```

- [ ] **Step 2: Bundle and verify**

Run: `bundle install`
Expected: `commonmarker` installed.

- [ ] **Step 3: Smoke-test in Rails console**

Run:
```bash
bin/rails runner 'puts Commonmarker.to_html("**hello** world")'
```
Expected: `<p><strong>hello</strong> world</p>`.

- [ ] **Step 4: Commit**

```bash
git add Gemfile Gemfile.lock
git commit -m "Add commonmarker gem for narration markdown rendering"
```

---

## Phase 2 — View models

### Task 6: Player::PlayerCharacterViewModel (asymmetry-protected)

**Files:**
- Create: `app/view_models/player/player_character_view_model.rb`
- Create: `spec/view_models/player/player_character_view_model_spec.rb`

- [ ] **Step 1: Write the failing spec (asymmetry-checked)**

Create `spec/view_models/player/player_character_view_model_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Player::PlayerCharacterViewModel, type: :view_model do
  let(:campaign) { create(:campaign) }
  let(:pc)       { create(:player_character, campaign:, name: "Aragorn", role: "pc", notes: "SECRET DM NOTE") }

  describe "exposed attributes" do
    subject { described_class.new(pc) }

    it "exposes player-safe fields" do
      expect(subject.to_h).to include(
        id: pc.id,
        name: "Aragorn",
        role: "pc",
        class_name: pc.class_name,
        level: pc.level,
        pronouns: pc.pronouns
      )
    end

    it "does not expose notes" do
      expect(subject.to_h).not_to have_key(:notes)
    end
  end

  describe "asymmetry" do
    before do
      faction = create(:faction, campaign:)
      create(:faction_secret, faction:, content: "hidden faction info")
      npc = create(:npc, campaign:)
      create(:npc_secret, npc:, content: "hidden npc info")
      scene = create(:scene, campaign:)
      create(:scene_secret, scene:, content: "hidden scene info")
    end

    it "does not leak secrets of related records" do
      vm = described_class.new(pc)
      expect(vm).not_to leak_secrets_of(*FactionSecret.all, *NpcSecret.all, *SceneSecret.all)
      expect(vm.to_h.to_s).not_to include("SECRET DM NOTE")
    end
  end
end
```

- [ ] **Step 2: Run spec to verify failure**

Run: `bundle exec rspec spec/view_models/player/player_character_view_model_spec.rb`
Expected: FAIL — class undefined.

- [ ] **Step 3: Write the view model**

Create `app/view_models/player/player_character_view_model.rb`:

```ruby
module Player
  class PlayerCharacterViewModel < ApplicationViewModel
    def initialize(player_character)
      @pc = player_character
    end

    expose :id
    expose :name
    expose :role
    expose :class_name
    expose :level
    expose :pronouns

    private

    attr_reader :pc

    def id         = pc.id
    def name       = pc.name
    def role       = pc.role
    def class_name = pc.class_name
    def level      = pc.level
    def pronouns   = pc.pronouns
  end
end
```

- [ ] **Step 4: Run spec to verify green**

Run: `bundle exec rspec spec/view_models/player/player_character_view_model_spec.rb`
Expected: green.

- [ ] **Step 5: Commit**

```bash
git add app/view_models/player/player_character_view_model.rb \
        spec/view_models/player/player_character_view_model_spec.rb
git commit -m "Add Player::PlayerCharacterViewModel (no notes leak)"
```

---

### Task 7: Narrator::* view models (DM-side, expose secrets)

**Files:**
- Create: `app/view_models/narrator/player_character_view_model.rb`
- Create: `app/view_models/narrator/scene_secret_view_model.rb`
- Create: `app/view_models/narrator/campaign_view_model.rb`
- Create: `app/view_models/narrator/scene_view_model.rb`
- Create: `app/view_models/narrator/faction_view_model.rb`
- Create: `app/view_models/narrator/npc_view_model.rb`
- Create: matching spec files under `spec/view_models/narrator/`

This task creates the DM-side VM family. **These are NOT asymmetry-protected** — they intentionally include secrets, so they have NO `leak_secrets_of` spec. They're only ever used by `Narrator::PromptBuilder`, never by `Play::*Component`.

- [ ] **Step 1: Write the Narrator::PlayerCharacterViewModel spec**

Create `spec/view_models/narrator/player_character_view_model_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Narrator::PlayerCharacterViewModel, type: :view_model do
  let(:pc) { create(:player_character, name: "Aragorn", notes: "DM NOTE") }

  it "exposes name, role, class_name, level, pronouns, and notes" do
    vm = described_class.new(pc)
    expect(vm.to_h).to include(
      name: "Aragorn",
      role: "pc",
      class_name: pc.class_name,
      level: pc.level,
      pronouns: pc.pronouns,
      notes: "DM NOTE"
    )
  end
end
```

- [ ] **Step 2: Write the model**

Create `app/view_models/narrator/player_character_view_model.rb`:

```ruby
module Narrator
  class PlayerCharacterViewModel < ApplicationViewModel
    def initialize(pc)
      @pc = pc
    end

    expose :name
    expose :role
    expose :class_name
    expose :level
    expose :pronouns
    expose :notes

    private

    attr_reader :pc

    def name       = pc.name
    def role       = pc.role
    def class_name = pc.class_name
    def level      = pc.level
    def pronouns   = pc.pronouns
    def notes      = pc.notes
  end
end
```

- [ ] **Step 3: Write Narrator::SceneSecretViewModel + spec**

Create `spec/view_models/narrator/scene_secret_view_model_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Narrator::SceneSecretViewModel, type: :view_model do
  let(:secret) { create(:scene_secret, label: "Encounter map", content: "2 skeletons at the door") }

  it "exposes label and content" do
    vm = described_class.new(secret)
    expect(vm.to_h).to include(label: "Encounter map", content: "2 skeletons at the door")
  end
end
```

Create `app/view_models/narrator/scene_secret_view_model.rb`:

```ruby
module Narrator
  class SceneSecretViewModel < ApplicationViewModel
    def initialize(secret)
      @secret = secret
    end

    expose :label
    expose :content

    private

    attr_reader :secret

    def label   = secret.label
    def content = secret.content
  end
end
```

- [ ] **Step 4: Write Narrator::FactionViewModel (with secrets) + spec**

Create `spec/view_models/narrator/faction_view_model_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Narrator::FactionViewModel, type: :view_model do
  let(:faction) { create(:faction, name: "Cult of Myrkul", public_description: "Worshippers.") }

  before { create(:faction_secret, faction:, label: "Secret 1", content: "hidden") }

  it "exposes name, public_description, and secrets as Narrator VMs" do
    vm = described_class.new(faction)
    expect(vm.name).to eq("Cult of Myrkul")
    expect(vm.public_description).to eq("Worshippers.")
    expect(vm.secrets).to all(be_a(Narrator::FactionSecretViewModel))
    expect(vm.to_h[:secrets].first).to include(label: "Secret 1", content: "hidden")
  end
end
```

Create `app/view_models/narrator/faction_view_model.rb`:

```ruby
module Narrator
  class FactionViewModel < ApplicationViewModel
    def initialize(faction)
      @faction = faction
    end

    expose :name
    expose :public_description
    expose :secrets

    private

    attr_reader :faction

    def name               = faction.name
    def public_description = faction.public_description
    def secrets            = faction.secrets.order(:label).map { Narrator::FactionSecretViewModel.new(_1) }
  end
end
```

- [ ] **Step 5: Write Narrator::NpcViewModel (mirrors faction) + spec**

Create `spec/view_models/narrator/npc_view_model_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Narrator::NpcViewModel, type: :view_model do
  let(:npc) { create(:npc, name: "Aldridge", public_description: "Captain.", location: "Gate") }

  before { create(:npc_secret, npc:, label: "Knows", content: "hidden npc fact") }

  it "exposes name, description, location, and secrets" do
    vm = described_class.new(npc)
    expect(vm.name).to eq("Aldridge")
    expect(vm.public_description).to eq("Captain.")
    expect(vm.location).to eq("Gate")
    expect(vm.secrets).to all(be_a(Narrator::NpcSecretViewModel))
  end
end
```

Create `app/view_models/narrator/npc_view_model.rb`:

```ruby
module Narrator
  class NpcViewModel < ApplicationViewModel
    def initialize(npc)
      @npc = npc
    end

    expose :name
    expose :public_description
    expose :location
    expose :secrets

    private

    attr_reader :npc

    def name               = npc.name
    def public_description = npc.public_description
    def location           = npc.location
    def secrets            = npc.secrets.order(:label).map { Narrator::NpcSecretViewModel.new(_1) }
  end
end
```

- [ ] **Step 6: Write Narrator::SceneViewModel + spec**

Create `spec/view_models/narrator/scene_view_model_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Narrator::SceneViewModel, type: :view_model do
  let(:scene) { create(:scene, title: "Cemetery", summary: "An old cemetery.") }

  before { create(:scene_secret, scene:, label: "Encounter", content: "2 skeletons") }

  it "exposes title, summary, and scene_secrets" do
    vm = described_class.new(scene)
    expect(vm.title).to eq("Cemetery")
    expect(vm.summary).to eq("An old cemetery.")
    expect(vm.scene_secrets).to all(be_a(Narrator::SceneSecretViewModel))
    expect(vm.to_h[:scene_secrets].first).to include(label: "Encounter", content: "2 skeletons")
  end
end
```

Create `app/view_models/narrator/scene_view_model.rb`:

```ruby
module Narrator
  class SceneViewModel < ApplicationViewModel
    def initialize(scene)
      @scene = scene
    end

    expose :title
    expose :summary
    expose :scene_secrets

    private

    attr_reader :scene

    def title         = scene.title
    def summary       = scene.summary
    def scene_secrets = scene.scene_secrets.order(:label).map { Narrator::SceneSecretViewModel.new(_1) }
  end
end
```

- [ ] **Step 7: Write Narrator::CampaignViewModel + spec**

Create `spec/view_models/narrator/campaign_view_model_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Narrator::CampaignViewModel, type: :view_model do
  let(:campaign) { create(:campaign, name: "Phandalin", description: "Hook text.") }

  before do
    create(:player_character, campaign:, name: "Aragorn",  role: "pc",        notes: "main")
    create(:player_character, campaign:, name: "Caine",    role: "companion", notes: nil)
    create(:faction, campaign:)
    create(:npc, campaign:)
  end

  it "exposes name, description, factions, npcs, and pcs/companions split by role" do
    vm = described_class.new(campaign)
    expect(vm.name).to eq("Phandalin")
    expect(vm.description).to eq("Hook text.")
    expect(vm.factions).to all(be_a(Narrator::FactionViewModel))
    expect(vm.npcs).to all(be_a(Narrator::NpcViewModel))
    expect(vm.pcs.map(&:name)).to eq([ "Aragorn" ])
    expect(vm.companions.map(&:name)).to eq([ "Caine" ])
  end

  it "exposes main_character when set" do
    aragorn = campaign.player_characters.find_by(name: "Aragorn")
    campaign.update!(main_character: aragorn)
    expect(described_class.new(campaign).main_character.name).to eq("Aragorn")
  end

  it "returns nil main_character when unset" do
    expect(described_class.new(campaign).main_character).to be_nil
  end
end
```

Create `app/view_models/narrator/campaign_view_model.rb`:

```ruby
module Narrator
  class CampaignViewModel < ApplicationViewModel
    def initialize(campaign)
      @campaign = campaign
    end

    expose :name
    expose :description
    expose :factions
    expose :npcs
    expose :pcs
    expose :companions
    expose :main_character

    private

    attr_reader :campaign

    def name        = campaign.name
    def description = campaign.description
    def factions    = campaign.factions.order(:name).map { Narrator::FactionViewModel.new(_1) }
    def npcs        = campaign.npcs.order(:name).map { Narrator::NpcViewModel.new(_1) }
    def pcs         = campaign.player_characters.pcs.order(:name).map { Narrator::PlayerCharacterViewModel.new(_1) }
    def companions  = campaign.player_characters.companions.order(:name).map { Narrator::PlayerCharacterViewModel.new(_1) }

    def main_character
      return nil unless campaign.main_character
      Narrator::PlayerCharacterViewModel.new(campaign.main_character)
    end
  end
end
```

- [ ] **Step 8: Run all Narrator VM specs**

Run: `bundle exec rspec spec/view_models/narrator/`
Expected: green.

- [ ] **Step 9: Commit**

```bash
git add app/view_models/narrator/ spec/view_models/narrator/
git commit -m "Add Narrator::* VMs (DM-side, with secrets) for Phase 9.1 prompt builder"
```

---

### Task 8: Player::SceneStateViewModel — derive turn state from events

**Files:**
- Create: `app/view_models/player/scene_state_view_model.rb`
- Create: `spec/view_models/player/scene_state_view_model_spec.rb`

This VM is the load-bearing state-derivation layer. Phase detection rules from spec section "State derivation rules."

- [ ] **Step 1: Write the failing spec with phase-coverage tests**

Create `spec/view_models/player/scene_state_view_model_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Player::SceneStateViewModel, type: :view_model do
  let(:campaign) { create(:campaign) }
  let!(:aragorn) { create(:player_character, campaign:, name: "Aragorn", role: "pc") }
  let!(:caine)   { create(:player_character, campaign:, name: "Caine",   role: "companion") }
  before         { campaign.update!(main_character: aragorn) }
  let(:scene)    { create(:scene, campaign:) }

  describe "#phase" do
    it "is :framing when no events exist" do
      expect(described_class.new(scene).phase).to eq(:framing)
    end

    it "is :collecting when a declaration exists but PCs still undeclared" do
      # An empty party would skip collecting entirely; ensure there ARE PCs
      create(:player_character, campaign:, name: "Patric", role: "pc")
      create(:event, scene:, kind: "pc_declaration", pc: aragorn, turn_number: 1)
      expect(described_class.new(scene).phase).to eq(:collecting)
    end

    it "is :collecting when all PCs declared but companion check not yet offered" do
      create(:event, scene:, kind: "pc_declaration", pc: aragorn, turn_number: 1)
      expect(described_class.new(scene).phase).to eq(:collecting)
    end

    it "is :resolving when all PCs declared and companion check offered (or no companions)" do
      campaign.player_characters.companions.destroy_all
      create(:event, scene:, kind: "pc_declaration", pc: aragorn, turn_number: 1)
      # No companions exist — companion_prompt_offered? is vacuously true
      # Phase is :resolving only when a resolution job is in flight; otherwise treat as ready-to-resolve
      # For this VM, expose :ready_to_resolve as a sub-state of collecting that the controller acts on
      expect(described_class.new(scene)).to be_ready_to_resolve
    end

    it "is :awaiting_roll when most recent narration ends with an open chip" do
      create(:event, scene:, kind: "pc_declaration", pc: aragorn, turn_number: 1)
      create(:event, scene:, kind: "narration", turn_number: 1,
             payload: { "text" => "You see... [[1d20+3 — Aragorn Perception]]" })
      expect(described_class.new(scene).phase).to eq(:awaiting_roll)
    end

    it "is :idle when most recent narration ends at a handoff (?)" do
      create(:event, scene:, kind: "pc_declaration", pc: aragorn, turn_number: 1)
      create(:event, scene:, kind: "narration", turn_number: 1,
             payload: { "text" => "The door opens. What does Aragorn do?" })
      expect(described_class.new(scene).phase).to eq(:idle)
    end
  end

  describe "#undeclared_pcs_this_turn" do
    it "lists PCs without a declaration since last clean narration" do
      patric = create(:player_character, campaign:, name: "Patric", role: "pc")
      create(:event, scene:, kind: "pc_declaration", pc: aragorn, turn_number: 1)
      vm = described_class.new(scene)
      expect(vm.undeclared_pcs_this_turn.map(&:name)).to contain_exactly("Patric")
    end

    it "is empty after a clean narration" do
      create(:event, scene:, kind: "pc_declaration", pc: aragorn, turn_number: 1)
      create(:event, scene:, kind: "narration", turn_number: 1,
             payload: { "text" => "What do you do?" })
      expect(described_class.new(scene).undeclared_pcs_this_turn).to be_empty
    end
  end

  describe "#companion_prompt_offered?" do
    it "is vacuously true when no companions exist" do
      campaign.player_characters.companions.destroy_all
      expect(described_class.new(scene).companion_prompt_offered?).to eq(true)
    end

    it "is false when companions exist but no companion prompt this turn" do
      create(:event, scene:, kind: "pc_declaration", pc: aragorn, turn_number: 1)
      expect(described_class.new(scene).companion_prompt_offered?).to eq(false)
    end

    it "is true after a gm_collection_prompt with the companion-check label this turn" do
      create(:event, scene:, kind: "pc_declaration", pc: aragorn, turn_number: 1)
      create(:event, scene:, kind: "gm_collection_prompt", turn_number: 1,
             payload: { "text" => "Anything for Caine, or shall I run them?", "kind" => "companion_check" })
      expect(described_class.new(scene).companion_prompt_offered?).to eq(true)
    end
  end

  describe "#current_turn_number" do
    it "is 1 in framing phase" do
      expect(described_class.new(scene).current_turn_number).to eq(1)
    end

    it "tracks turn number from events" do
      create(:event, scene:, kind: "pc_declaration", pc: aragorn, turn_number: 1)
      create(:event, scene:, kind: "narration",                   turn_number: 1, payload: { "text" => "What now?" })
      create(:event, scene:, kind: "pc_declaration", pc: aragorn, turn_number: 2)
      expect(described_class.new(scene).current_turn_number).to eq(2)
    end
  end
end
```

- [ ] **Step 2: Run spec to verify it fails**

Run: `bundle exec rspec spec/view_models/player/scene_state_view_model_spec.rb`
Expected: FAIL — class undefined.

- [ ] **Step 3: Implement the view model**

Create `app/view_models/player/scene_state_view_model.rb`:

```ruby
module Player
  class SceneStateViewModel < ApplicationViewModel
    OPEN_CHIP_RE  = /\[\[[^\]]*\z/
    HANDOFF_RE    = /\?\s*\z/

    def initialize(scene)
      @scene = scene
    end

    def phase
      return :framing if events.empty?
      return :awaiting_roll if last_narration_open_chip?
      return :idle          if last_narration_handoff?
      :collecting
    end

    def ready_to_resolve?
      phase == :collecting && undeclared_pcs_this_turn.empty? && companion_prompt_offered?
    end

    def current_turn_number
      return 1 if events.empty?
      events.maximum(:turn_number) || 1
    end

    def declared_this_turn
      pc_declarations_this_turn.map(&:pc).compact
    end

    def undeclared_pcs_this_turn
      campaign.player_characters.pcs.order(:name).reject { declared_this_turn.include?(_1) }
    end

    def undeclared_companions_this_turn
      campaign.player_characters.companions.order(:name).reject { declared_this_turn.include?(_1) }
    end

    def companion_prompt_offered?
      return true if campaign.player_characters.companions.none?
      gm_collection_prompts_this_turn.any? { _1.payload["kind"] == "companion_check" }
    end

    def composer_enabled?
      %i[idle collecting].include?(phase)
    end

    private

    attr_reader :scene

    def campaign = scene.campaign

    def events
      @events ||= scene.events.order(:occurred_at, :id)
    end

    def events_since_last_clean_narration
      idx = events.to_a.rindex { |e| e.kind == "narration" && (e.payload["text"] || "") =~ HANDOFF_RE }
      idx ? events.to_a[(idx + 1)..] : events.to_a
    end

    def pc_declarations_this_turn
      events_since_last_clean_narration.select { _1.kind == "pc_declaration" }
    end

    def gm_collection_prompts_this_turn
      events_since_last_clean_narration.select { _1.kind == "gm_collection_prompt" }
    end

    def last_narration
      events.reverse.find { _1.kind == "narration" }
    end

    def last_narration_text
      (last_narration&.payload || {})["text"].to_s
    end

    def last_narration_open_chip?
      return false unless last_narration
      last_narration_text =~ OPEN_CHIP_RE
    end

    def last_narration_handoff?
      return false unless last_narration
      last_narration_text =~ HANDOFF_RE
    end
  end
end
```

- [ ] **Step 4: Run spec to green**

Run: `bundle exec rspec spec/view_models/player/scene_state_view_model_spec.rb`
Expected: green.

- [ ] **Step 5: Commit**

```bash
git add app/view_models/player/scene_state_view_model.rb \
        spec/view_models/player/scene_state_view_model_spec.rb
git commit -m "Add Player::SceneStateViewModel (event-derived turn state)"
```

---

## Phase 3 — Admin CRUD

### Task 9: Admin::PlayerCharactersController + components + routes

**Files:**
- Create: `app/controllers/admin/player_characters_controller.rb`
- Create: `app/components/admin/player_characters/{index,show,form,row}_component.{rb,html.erb}`
- Modify: `config/routes/admin.rb` — nest `player_characters` under `:campaigns`
- Modify: `app/components/admin/campaigns/show_component.html.erb` — add link to PCs index
- Modify: `app/components/admin/campaigns/form_component.{rb,html.erb}` — add `main_character_id` select (when PCs exist)
- Create: `spec/requests/admin/player_characters_spec.rb`
- Create: `spec/components/admin/player_characters/{index,show,form,row}_component_spec.rb`

Pattern: copy `Admin::Scenes` structure verbatim, substitute names.

- [ ] **Step 1: Write a failing request spec**

Create `spec/requests/admin/player_characters_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Admin::PlayerCharacters", type: :request do
  let(:user)     { create(:user) }
  let(:campaign) { create(:campaign, user:) }

  before { host! "admin.gygaxagain.com" }

  describe "unauthenticated" do
    it "redirects to sign-in for index" do
      get admin_campaign_player_characters_path(campaign)
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "authenticated" do
    before { sign_in user }

    describe "GET /admin/campaigns/:id/player_characters" do
      it "renders the index" do
        create(:player_character, campaign:, name: "Aragorn")
        get admin_campaign_player_characters_path(campaign)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Aragorn")
      end
    end

    describe "POST /admin/campaigns/:id/player_characters" do
      it "creates a PC" do
        expect {
          post admin_campaign_player_characters_path(campaign), params: {
            player_character: { name: "Aragorn", role: "pc", class_name: "Ranger", level: 1 }
          }
        }.to change { campaign.player_characters.count }.by(1)
        expect(response).to redirect_to(admin_campaign_player_characters_path(campaign))
      end

      it "re-renders the form on validation failure" do
        post admin_campaign_player_characters_path(campaign), params: {
          player_character: { name: "", role: "pc" }
        }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    describe "PATCH /admin/campaigns/:id/player_characters/:id" do
      it "updates" do
        pc = create(:player_character, campaign:, name: "Aragorn")
        patch admin_campaign_player_character_path(campaign, pc),
              params: { player_character: { name: "Strider" } }
        expect(pc.reload.name).to eq("Strider")
      end
    end

    describe "DELETE /admin/campaigns/:id/player_characters/:id" do
      it "destroys" do
        pc = create(:player_character, campaign:)
        expect {
          delete admin_campaign_player_character_path(campaign, pc)
        }.to change { campaign.player_characters.count }.by(-1)
      end
    end

    describe "scoping" do
      it "404s on another user's campaign" do
        other = create(:campaign)
        get admin_campaign_player_characters_path(other)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
```

- [ ] **Step 2: Run spec to verify failure**

Run: `bundle exec rspec spec/requests/admin/player_characters_spec.rb`
Expected: FAIL — routes undefined.

- [ ] **Step 3: Add routes**

Modify `config/routes/admin.rb` — inside the `resources :campaigns` block (alongside `resources :scenes`):

```ruby
      resources :player_characters
```

- [ ] **Step 4: Write the controller**

Create `app/controllers/admin/player_characters_controller.rb`:

```ruby
module Admin
  class PlayerCharactersController < Admin::ApplicationController
    before_action :authenticate_user!
    before_action :load_campaign
    before_action :load_player_character, only: %i[show edit update destroy]

    def index
      pcs = @campaign.player_characters.order(:name)
      render Admin::PlayerCharacters::IndexComponent.new(campaign: @campaign, player_characters: pcs)
    end

    def show
      render Admin::PlayerCharacters::ShowComponent.new(campaign: @campaign, player_character: @player_character)
    end

    def new
      @player_character = @campaign.player_characters.new(role: "pc")
      render Admin::PlayerCharacters::FormComponent.new(campaign: @campaign, player_character: @player_character)
    end

    def create
      @player_character = @campaign.player_characters.new(player_character_params)
      if @player_character.save
        redirect_to admin_campaign_player_characters_path(@campaign), notice: "PC created."
      else
        render Admin::PlayerCharacters::FormComponent.new(campaign: @campaign, player_character: @player_character),
               status: :unprocessable_content
      end
    end

    def edit
      render Admin::PlayerCharacters::FormComponent.new(campaign: @campaign, player_character: @player_character)
    end

    def update
      if @player_character.update(player_character_params)
        redirect_to admin_campaign_player_characters_path(@campaign), notice: "PC updated."
      else
        render Admin::PlayerCharacters::FormComponent.new(campaign: @campaign, player_character: @player_character),
               status: :unprocessable_content
      end
    end

    def destroy
      @player_character.destroy!
      redirect_to admin_campaign_player_characters_path(@campaign), notice: "PC removed."
    end

    private

    def load_campaign
      @campaign = current_user.campaigns.find(params[:campaign_id])
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    def load_player_character
      @player_character = @campaign.player_characters.find(params[:id])
    end

    def player_character_params
      params.require(:player_character).permit(:name, :pronouns, :class_name, :level, :role, :notes)
    end
  end
end
```

- [ ] **Step 5: Write the four components**

Create `app/components/admin/player_characters/index_component.rb`:

```ruby
module Admin
  module PlayerCharacters
    class IndexComponent < ViewComponent::Base
      def initialize(campaign:, player_characters:)
        @campaign = campaign
        @player_characters = player_characters
      end

      attr_reader :campaign, :player_characters
    end
  end
end
```

Create `app/components/admin/player_characters/index_component.html.erb`:

```erb
<h1>Player Characters — <%= campaign.name %></h1>
<p>
  <%= link_to "New PC", new_admin_campaign_player_character_path(campaign), class: "btn" %>
  <%= link_to "← Back to campaign", admin_campaign_path(campaign) %>
</p>
<table>
  <thead>
    <tr><th>Name</th><th>Role</th><th>Class</th><th>Level</th><th></th></tr>
  </thead>
  <tbody>
    <% player_characters.each do |pc| %>
      <%= render Admin::PlayerCharacters::RowComponent.new(campaign:, player_character: pc) %>
    <% end %>
  </tbody>
</table>
```

Create `app/components/admin/player_characters/row_component.rb`:

```ruby
module Admin
  module PlayerCharacters
    class RowComponent < ViewComponent::Base
      def initialize(campaign:, player_character:)
        @campaign = campaign
        @pc = player_character
      end

      attr_reader :campaign, :pc
    end
  end
end
```

Create `app/components/admin/player_characters/row_component.html.erb`:

```erb
<tr>
  <td><%= link_to pc.name, admin_campaign_player_character_path(campaign, pc) %></td>
  <td><%= pc.role %></td>
  <td><%= pc.class_name %></td>
  <td><%= pc.level %></td>
  <td>
    <%= link_to "Edit", edit_admin_campaign_player_character_path(campaign, pc) %>
    <%= button_to "Delete", admin_campaign_player_character_path(campaign, pc), method: :delete,
                  data: { turbo_confirm: "Remove #{pc.name}?" } %>
  </td>
</tr>
```

Create `app/components/admin/player_characters/show_component.rb`:

```ruby
module Admin
  module PlayerCharacters
    class ShowComponent < ViewComponent::Base
      def initialize(campaign:, player_character:)
        @campaign = campaign
        @pc = player_character
      end

      attr_reader :campaign, :pc
    end
  end
end
```

Create `app/components/admin/player_characters/show_component.html.erb`:

```erb
<h1><%= pc.name %></h1>
<p>
  <strong>Role:</strong> <%= pc.role %><br>
  <strong>Class:</strong> <%= pc.class_name %><br>
  <strong>Level:</strong> <%= pc.level %><br>
  <strong>Pronouns:</strong> <%= pc.pronouns %><br>
</p>
<% if pc.notes.present? %>
  <h2>Notes (DM-only)</h2>
  <pre><%= pc.notes %></pre>
<% end %>
<p>
  <%= link_to "Edit", edit_admin_campaign_player_character_path(campaign, pc) %>
  <%= link_to "← All PCs", admin_campaign_player_characters_path(campaign) %>
</p>
```

Create `app/components/admin/player_characters/form_component.rb`:

```ruby
module Admin
  module PlayerCharacters
    class FormComponent < ViewComponent::Base
      def initialize(campaign:, player_character:)
        @campaign = campaign
        @pc = player_character
      end

      attr_reader :campaign, :pc

      def form_url
        if pc.persisted?
          admin_campaign_player_character_path(campaign, pc)
        else
          admin_campaign_player_characters_path(campaign)
        end
      end

      def form_method = pc.persisted? ? :patch : :post
      def heading     = pc.persisted? ? "Edit #{pc.name}" : "New PC"
      def submit      = pc.persisted? ? "Save" : "Create"
    end
  end
end
```

Create `app/components/admin/player_characters/form_component.html.erb`:

```erb
<h1><%= heading %></h1>
<%= form_with model: pc, url: form_url, method: form_method do |f| %>
  <% if pc.errors.any? %>
    <ul class="errors">
      <% pc.errors.full_messages.each do |m| %><li><%= m %></li><% end %>
    </ul>
  <% end %>
  <div><%= f.label :name %><%= f.text_field :name %></div>
  <div><%= f.label :role %><%= f.select :role, PlayerCharacter::ROLES.map { [ _1, _1 ] } %></div>
  <div><%= f.label :pronouns %><%= f.text_field :pronouns %></div>
  <div><%= f.label :class_name %><%= f.text_field :class_name %></div>
  <div><%= f.label :level %><%= f.number_field :level %></div>
  <div><%= f.label :notes, "Notes (DM-only)" %><%= f.text_area :notes, rows: 6 %></div>
  <%= f.submit submit %>
<% end %>
<p><%= link_to "← Cancel", admin_campaign_player_characters_path(campaign) %></p>
```

- [ ] **Step 6: Run all admin request + component specs**

Run: `bundle exec rspec spec/requests/admin/player_characters_spec.rb`
Expected: green.

- [ ] **Step 7: Update Admin::Campaigns::ShowComponent to link to PCs index**

Modify `app/components/admin/campaigns/show_component.html.erb` to add (alongside other "manage" links):

```erb
<p><%= link_to "Manage PCs (#{campaign.player_characters.count})", admin_campaign_player_characters_path(campaign) %></p>
```

- [ ] **Step 8: Commit**

```bash
git add app/controllers/admin/player_characters_controller.rb \
        app/components/admin/player_characters/ \
        app/components/admin/campaigns/show_component.html.erb \
        config/routes/admin.rb \
        spec/requests/admin/player_characters_spec.rb
git commit -m "Add Admin::PlayerCharacters CRUD"
```

---

### Task 10: Admin::SceneSecretsController + components + routes

**Files:**
- Create: `app/controllers/admin/scene_secrets_controller.rb`
- Create: `app/components/admin/scene_secrets/{index,show,form,row}_component.{rb,html.erb}`
- Modify: `config/routes/admin.rb` — nest `scene_secrets` under `:scenes`
- Modify: `app/components/admin/scenes/show_component.html.erb` (if it exists; if not, the scenes index/show pattern) — add link to scene secrets
- Create: `spec/requests/admin/scene_secrets_spec.rb`

**Pattern: identical to Task 9, swap player_characters → scene_secrets and campaign → scene.**

- [ ] **Step 1: Write the failing request spec**

Create `spec/requests/admin/scene_secrets_spec.rb` modeled exactly on the player_characters spec from Task 9 (parameterize on campaign → scene; fields are `label` and `content`):

```ruby
require "rails_helper"

RSpec.describe "Admin::SceneSecrets", type: :request do
  let(:user)     { create(:user) }
  let(:campaign) { create(:campaign, user:) }
  let(:scene)    { create(:scene, campaign:) }

  before { host! "admin.gygaxagain.com" }

  describe "authenticated" do
    before { sign_in user }

    it "GET index renders" do
      create(:scene_secret, scene:, label: "Encounter")
      get admin_campaign_scene_scene_secrets_path(campaign, scene)
      expect(response).to be_ok
      expect(response.body).to include("Encounter")
    end

    it "POST creates" do
      expect {
        post admin_campaign_scene_scene_secrets_path(campaign, scene), params: {
          scene_secret: { label: "Encounter", content: "2 skeletons" }
        }
      }.to change { scene.scene_secrets.count }.by(1)
    end

    it "PATCH updates" do
      secret = create(:scene_secret, scene:)
      patch admin_campaign_scene_scene_secret_path(campaign, scene, secret),
            params: { scene_secret: { content: "updated content" } }
      expect(secret.reload.content).to eq("updated content")
    end

    it "DELETE destroys" do
      secret = create(:scene_secret, scene:)
      expect {
        delete admin_campaign_scene_scene_secret_path(campaign, scene, secret)
      }.to change { scene.scene_secrets.count }.by(-1)
    end

    it "404s on another user's scene" do
      other = create(:scene)
      get admin_campaign_scene_scene_secrets_path(other.campaign, other)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "unauthenticated" do
    it "redirects to sign-in" do
      get admin_campaign_scene_scene_secrets_path(campaign, scene)
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
```

- [ ] **Step 2: Run spec to verify failure**

Run: `bundle exec rspec spec/requests/admin/scene_secrets_spec.rb`
Expected: FAIL — routes undefined.

- [ ] **Step 3: Add routes**

In `config/routes/admin.rb`, inside `resources :scenes` (alongside `resource :closure`, `resource :audit`):

```ruby
        resources :scene_secrets
```

- [ ] **Step 4: Write the controller**

Create `app/controllers/admin/scene_secrets_controller.rb` — same structure as `player_characters_controller.rb`, parameterized on `scene` and the `:label, :content` permit list. Use the same `load_campaign` + `load_scene` + `load_scene_secret` before-action pattern.

```ruby
module Admin
  class SceneSecretsController < Admin::ApplicationController
    before_action :authenticate_user!
    before_action :load_campaign_and_scene
    before_action :load_scene_secret, only: %i[show edit update destroy]

    def index
      secrets = @scene.scene_secrets.order(:label)
      render Admin::SceneSecrets::IndexComponent.new(campaign: @campaign, scene: @scene, scene_secrets: secrets)
    end

    def show
      render Admin::SceneSecrets::ShowComponent.new(campaign: @campaign, scene: @scene, scene_secret: @scene_secret)
    end

    def new
      @scene_secret = @scene.scene_secrets.new
      render Admin::SceneSecrets::FormComponent.new(campaign: @campaign, scene: @scene, scene_secret: @scene_secret)
    end

    def create
      @scene_secret = @scene.scene_secrets.new(scene_secret_params)
      if @scene_secret.save
        redirect_to admin_campaign_scene_scene_secrets_path(@campaign, @scene), notice: "Scene secret created."
      else
        render Admin::SceneSecrets::FormComponent.new(campaign: @campaign, scene: @scene, scene_secret: @scene_secret),
               status: :unprocessable_content
      end
    end

    def edit
      render Admin::SceneSecrets::FormComponent.new(campaign: @campaign, scene: @scene, scene_secret: @scene_secret)
    end

    def update
      if @scene_secret.update(scene_secret_params)
        redirect_to admin_campaign_scene_scene_secrets_path(@campaign, @scene), notice: "Scene secret updated."
      else
        render Admin::SceneSecrets::FormComponent.new(campaign: @campaign, scene: @scene, scene_secret: @scene_secret),
               status: :unprocessable_content
      end
    end

    def destroy
      @scene_secret.destroy!
      redirect_to admin_campaign_scene_scene_secrets_path(@campaign, @scene), notice: "Scene secret removed."
    end

    private

    def load_campaign_and_scene
      @campaign = current_user.campaigns.find(params[:campaign_id])
      @scene = @campaign.scenes.find(params[:scene_id])
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    def load_scene_secret
      @scene_secret = @scene.scene_secrets.find(params[:id])
    end

    def scene_secret_params
      params.require(:scene_secret).permit(:label, :content)
    end
  end
end
```

- [ ] **Step 5: Write the four components**

Create the four files in `app/components/admin/scene_secrets/` mirroring Task 9's pattern. Fields: `label` (text_field) and `content` (text_area, rows: 10). Index columns: Label, Content snippet, Edit/Delete. (Full template bodies follow Task 9's shape verbatim — substitute `scene_secret`/`scene`/`scene_secrets` accordingly.)

Skeleton for FormComponent:

```ruby
module Admin
  module SceneSecrets
    class FormComponent < ViewComponent::Base
      def initialize(campaign:, scene:, scene_secret:)
        @campaign = campaign
        @scene = scene
        @secret = scene_secret
      end
      attr_reader :campaign, :scene, :secret

      def form_url
        secret.persisted? ?
          admin_campaign_scene_scene_secret_path(campaign, scene, secret) :
          admin_campaign_scene_scene_secrets_path(campaign, scene)
      end
      def form_method = secret.persisted? ? :patch : :post
      def heading     = secret.persisted? ? "Edit scene secret" : "New scene secret"
      def submit      = secret.persisted? ? "Save" : "Create"
    end
  end
end
```

- [ ] **Step 6: Run the spec**

Run: `bundle exec rspec spec/requests/admin/scene_secrets_spec.rb`
Expected: green.

- [ ] **Step 7: Commit**

```bash
git add app/controllers/admin/scene_secrets_controller.rb \
        app/components/admin/scene_secrets/ \
        config/routes/admin.rb \
        spec/requests/admin/scene_secrets_spec.rb
git commit -m "Add Admin::SceneSecrets CRUD"
```

---

### Task 11: Admin::Campaigns form — main_character_id select

**Files:**
- Modify: `app/controllers/admin/campaigns_controller.rb` — add `:main_character_id` to permitted params
- Modify: `app/components/admin/campaigns/form_component.html.erb` — add select (conditional on PCs existing)
- Modify: `spec/requests/admin/campaigns_spec.rb` — add tests for main_character_id assignment

- [ ] **Step 1: Add failing spec for main_character_id assignment**

Append to `spec/requests/admin/campaigns_spec.rb`:

```ruby
  describe "main_character_id" do
    let(:user) { create(:user) }
    before { sign_in user; host! "admin.gygaxagain.com" }

    it "assigns the main character on update" do
      campaign = create(:campaign, user:)
      aragorn  = create(:player_character, campaign:, name: "Aragorn")
      patch admin_campaign_path(campaign), params: { campaign: { main_character_id: aragorn.id } }
      expect(campaign.reload.main_character).to eq(aragorn)
    end

    it "accepts nil (unsetting)" do
      campaign = create(:campaign, user:)
      aragorn  = create(:player_character, campaign:, name: "Aragorn")
      campaign.update!(main_character: aragorn)
      patch admin_campaign_path(campaign), params: { campaign: { main_character_id: "" } }
      expect(campaign.reload.main_character).to be_nil
    end
  end
```

- [ ] **Step 2: Run to verify failure**

Run: `bundle exec rspec spec/requests/admin/campaigns_spec.rb -e "main_character"`
Expected: FAIL — `main_character_id` not permitted.

- [ ] **Step 3: Permit `main_character_id`**

In `app/controllers/admin/campaigns_controller.rb`, add `:main_character_id` to the `campaign_params` permit list.

- [ ] **Step 4: Add select to the form template**

In `app/components/admin/campaigns/form_component.html.erb`, add (after existing fields, only when PCs exist):

```erb
<% if campaign.player_characters.pcs.any? %>
  <div>
    <%= f.label :main_character_id, "Main PC" %>
    <%= f.select :main_character_id,
                 campaign.player_characters.pcs.order(:name).pluck(:name, :id),
                 include_blank: "(none)" %>
  </div>
<% end %>
```

- [ ] **Step 5: Run specs**

Run: `bundle exec rspec spec/requests/admin/campaigns_spec.rb`
Expected: green.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/admin/campaigns_controller.rb \
        app/components/admin/campaigns/form_component.html.erb \
        spec/requests/admin/campaigns_spec.rb
git commit -m "Admin::Campaigns: select main PC after PCs exist"
```

---

## Phase 4 — LLM adapter extensions

### Task 12: Anthropic adapter — negative cache_breakpoints for messages

**Files:**
- Modify: `app/lib/llm/providers/anthropic.rb`
- Modify: `spec/lib/llm/providers/anthropic_spec.rb` (create if absent)

- [ ] **Step 1: Write the failing spec**

Append (or create) `spec/lib/llm/providers/anthropic_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Llm::Providers::Anthropic do
  describe "negative cache_breakpoints" do
    let(:adapter) { described_class.new(model: "claude-opus-4-7") }
    let(:system) { [ { type: "text", text: "rules" } ] }
    let(:messages) do
      [
        { role: "user",      content: "t1 input" },
        { role: "assistant", content: "t1 reply" },
        { role: "user",      content: "t2 input" }
      ]
    end

    it "applies cache_control to the message at the negative index" do
      body = adapter.send(:build_request_body,
                          system:, messages:,
                          max_tokens: 100,
                          cache_breakpoints: [ 0, -2 ],
                          stop_sequences: nil)

      # System block 0 gets cache_control
      expect(body[:system].first).to have_key(:cache_control)

      # Messages at index -2 (the assistant reply) gets cache_control on its content block
      target = body[:messages][-2]
      expect(target[:content]).to be_an(Array)
      expect(target[:content].first).to include(cache_control: { type: "ephemeral", ttl: "5m" })
    end

    it "leaves messages untouched when no negative breakpoints given" do
      body = adapter.send(:build_request_body,
                          system:, messages:,
                          max_tokens: 100,
                          cache_breakpoints: [ 0 ],
                          stop_sequences: nil)
      expect(body[:messages].map { _1[:content] }).to all(be_a(String))
    end
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `bundle exec rspec spec/lib/llm/providers/anthropic_spec.rb`
Expected: FAIL — negative indices aren't handled or `stop_sequences` kwarg absent.

- [ ] **Step 3: Extend the adapter**

Modify `app/lib/llm/providers/anthropic.rb`:

Add to `build_request_body` (replace the current implementation):

```ruby
def build_request_body(system:, messages:, max_tokens:, cache_breakpoints:, stop_sequences: nil)
  body = { model: model, max_tokens: max_tokens, messages: messages }

  if system.present?
    sys_bps, msg_bps = partition_cache_breakpoints(cache_breakpoints)
    body[:system]   = sys_bps.any? ? normalize_system(system, sys_bps) : system
    body[:messages] = msg_bps.any? ? normalize_messages(messages, msg_bps) : messages
  elsif cache_breakpoints.any?
    raise Llm::ConfigError, "cache_breakpoints requires a non-nil system parameter"
  end

  body[:stop_sequences] = stop_sequences if stop_sequences.present?
  body
end

def partition_cache_breakpoints(bps)
  sys, msg = [], []
  bps.each do |bp|
    index, ttl = bp.is_a?(Hash) ? [ bp.fetch(:index), bp.fetch(:ttl, :ephemeral_5m) ] : [ bp, :ephemeral_5m ]
    (index.negative? ? msg : sys) << { index: index, ttl: ttl }
  end
  [ sys, msg ]
end

def normalize_messages(messages, breakpoints)
  msgs = messages.map(&:dup)
  breakpoints.each do |bp|
    index = bp[:index]
    target = msgs[index]
    content_blocks =
      case target[:content]
      when String then [ { type: "text", text: target[:content] } ]
      when Array  then target[:content].map(&:dup)
      end
    content_blocks[0] = content_blocks[0].merge(cache_control: { type: "ephemeral", ttl: ttl_to_anthropic(bp[:ttl]) })
    target[:content] = content_blocks
    msgs[index] = target
  end
  msgs
end
```

Update both `#call` and `#call_streaming` to accept `stop_sequences:` kwarg (default `nil`) and pass it into `build_request_body`. (E.g., `def call(system: nil, messages:, max_tokens: 1024, cache_breakpoints: [], stop_sequences: nil)` and same for streaming, then `build_request_body(..., stop_sequences: stop_sequences)`.)

- [ ] **Step 4: Update existing call sites that use the old signature**

Run: `grep -rn "build_request_body" app/ spec/` to confirm only the adapter calls it. The public `call`/`call_streaming` get the new kwarg with a default of `nil` — call sites without `stop_sequences` keep working.

Run: `grep -rn "cache_breakpoints" app/ spec/` to find existing users. Confirm they don't pass negative indices yet. They should still work since `partition_cache_breakpoints` treats positive as system.

- [ ] **Step 5: Run all adapter specs and regressions**

Run: `bundle exec rspec spec/lib/llm/`
Expected: green.

- [ ] **Step 6: Commit**

```bash
git add app/lib/llm/providers/anthropic.rb spec/lib/llm/providers/anthropic_spec.rb
git commit -m "Anthropic adapter: negative cache_breakpoints + stop_sequences pass-through"
```

---

### Task 13: Llm::Call — thread stop_sequences

**Files:**
- Modify: `app/lib/llm/call.rb`
- Modify: `spec/lib/llm/call_spec.rb` (if exists; otherwise add to the existing test file)

- [ ] **Step 1: Locate the Llm::Call wrapper**

Run: `cat app/lib/llm/call.rb | head -80`. Identify `execute` and `execute_streaming` signatures. They forward kwargs to the underlying provider.

- [ ] **Step 2: Add `stop_sequences:` to both methods**

Modify `app/lib/llm/call.rb` to accept and forward `stop_sequences:` to the provider:

```ruby
def self.execute_streaming(prompt:, model:, &on_chunk)
  provider = provider_for(model)
  provider.call_streaming(
    system:            prompt.system,
    messages:          prompt.messages,
    cache_breakpoints: prompt.cache_breakpoints,
    stop_sequences:    prompt.stop_sequences,
    &on_chunk
  )
end
```

(And similarly for `execute`.)

- [ ] **Step 3: Update Narrator::Prompt to carry stop_sequences**

Modify `app/lib/narrator/prompt.rb`:

```ruby
module Narrator
  Prompt = Data.define(:system, :messages, :cache_breakpoints, :stop_sequences) do
    def to_call_kwargs
      { system:, messages:, cache_breakpoints:, stop_sequences: }
    end

    # ... keep existing to_s and helpers
  end
end
```

Update PromptBuilder construction sites to pass `stop_sequences: nil` for now (the rewrite in Task 15 will set them).

- [ ] **Step 4: Run llm spec suite**

Run: `bundle exec rspec spec/lib/llm/ spec/lib/narrator/prompt_spec.rb`
Expected: green.

- [ ] **Step 5: Commit**

```bash
git add app/lib/llm/call.rb app/lib/narrator/prompt.rb spec/lib/llm/ spec/lib/narrator/
git commit -m "Llm::Call: thread stop_sequences through to provider"
```

---

## Phase 5 — Narrator rewrite

### Task 14: Narrator::SystemPrompt — discipline template

**Files:**
- Modify: `app/lib/narrator/system_prompt.rb` — replace TEXT
- Modify: `spec/lib/narrator/system_prompt_spec.rb`

- [ ] **Step 1: Write the failing spec**

Create or update `spec/lib/narrator/system_prompt_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Narrator::SystemPrompt do
  describe ".text" do
    it "contains the discipline preamble" do
      expect(described_class.text).to include("A roleplaying game is a conversation.")
    end

    it "contains the three-character-type contract" do
      expect(described_class.text).to include("Player characters (PCs)")
      expect(described_class.text).to include("Companions")
      expect(described_class.text).to include("Non-party characters (NPCs)")
    end

    it "tells the model never to generate the turn marker" do
      expect(described_class.text).to include("never generate")
      expect(described_class.text).to include("[Turn N]")
    end

    it "tells the model to use the dice-chip syntax" do
      expect(described_class.text).to include("[[")
      expect(described_class.text).to include("expression — PC name")
    end

    it "contains placeholder markers for pc_names and companion_names" do
      expect(described_class.text).to include("{pc_names}")
      expect(described_class.text).to include("{companion_names}")
    end
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `bundle exec rspec spec/lib/narrator/system_prompt_spec.rb`
Expected: FAIL — text doesn't contain the new content.

- [ ] **Step 3: Replace the prompt text**

Modify `app/lib/narrator/system_prompt.rb` — replace `TEXT` with the verbatim discipline prompt from the spec's "System prompt (verbatim)" section. Copy it directly from the spec document; do not paraphrase.

- [ ] **Step 4: Run spec to green**

Run: `bundle exec rspec spec/lib/narrator/system_prompt_spec.rb`
Expected: green.

- [ ] **Step 5: Commit**

```bash
git add app/lib/narrator/system_prompt.rb spec/lib/narrator/system_prompt_spec.rb
git commit -m "Narrator::SystemPrompt: replace with Alexander-grounded discipline prompt"
```

---

### Task 15: Narrator::PromptBuilder — conversation-shaped rewrite

**Files:**
- Modify: `app/lib/narrator/prompt_builder.rb` (full rewrite)
- Modify: `spec/lib/narrator/prompt_builder_spec.rb`

- [ ] **Step 1: Replace the prompt-builder spec**

Rewrite `spec/lib/narrator/prompt_builder_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Narrator::PromptBuilder do
  let(:campaign) { create(:campaign, name: "Phandalin", description: "Hook.") }
  let!(:aragorn) { create(:player_character, campaign:, name: "Aragorn", role: "pc", notes: "PC notes") }
  let!(:caine)   { create(:player_character, campaign:, name: "Caine",   role: "companion") }
  before         { campaign.update!(main_character: aragorn) }
  let(:scene)    { create(:scene, campaign:, title: "Cemetery", summary: "Old graves.") }
  before         { create(:scene_secret, scene:, label: "Encounter", content: "2 skeletons") }

  context "framing call (zero events)" do
    subject(:prompt) { described_class.framing(scene:) }

    it "produces three system blocks" do
      expect(prompt.system.length).to eq(3)
      expect(prompt.system.map { _1[:type] }).to eq(%w[text text text])
    end

    it "interpolates PC and companion names into the system prompt" do
      expect(prompt.system[0][:text]).to include("Aragorn")
      expect(prompt.system[0][:text]).to include("Caine")
    end

    it "includes scene_secrets content in the scene context block" do
      expect(prompt.system[2][:text]).to include("2 skeletons")
    end

    it "messages contains only the framing kickoff" do
      expect(prompt.messages.length).to eq(1)
      expect(prompt.messages.first[:role]).to eq("user")
      expect(prompt.messages.first[:content]).to include("Scene start")
      expect(prompt.messages.first[:content]).to include("Aragorn")
    end

    it "sets stop_sequences to ]]" do
      expect(prompt.stop_sequences).to eq([ "]]" ])
    end

    it "sets cache_breakpoints for the three system blocks" do
      expect(prompt.cache_breakpoints).to include(0, 1, 2)
    end
  end

  context "resolution call (turn declarations collected)" do
    before do
      create(:event, scene:, kind: "pc_declaration", pc: aragorn, turn_number: 1,
             payload: { "text" => "I push the door open." })
    end

    subject(:prompt) do
      described_class.resolution(scene:, current_turn_declarations: [
        { pc: aragorn, text: "I push the door open." }
      ])
    end

    it "builds a user message labeled [Turn N]" do
      expect(prompt.messages.last[:role]).to eq("user")
      expect(prompt.messages.last[:content]).to include("[Turn 1]")
      expect(prompt.messages.last[:content]).to include("Aragorn declares: I push the door open.")
    end

    it "filters gm_collection_prompt events from history" do
      create(:event, scene:, kind: "gm_collection_prompt", turn_number: 1, payload: { "text" => "And the others?" })
      expect(prompt.messages.last[:content]).not_to include("And the others?")
    end

    it "adds a negative cache breakpoint on the second-to-last assistant when prior turns exist" do
      # Add a prior completed turn
      create(:event, scene:, kind: "pc_declaration", pc: aragorn, turn_number: 1, payload: { "text" => "look" })
      create(:event, scene:, kind: "narration", turn_number: 1, payload: { "text" => "You see things. What do you do?" })
      create(:event, scene:, kind: "pc_declaration", pc: aragorn, turn_number: 2, payload: { "text" => "open" })
      prompt2 = described_class.resolution(scene:, current_turn_declarations: [ { pc: aragorn, text: "open" } ])
      assistant_indices = prompt2.messages.each_with_index.select { |m, _| m[:role] == "assistant" }.map(&:last)
      expect(prompt2.cache_breakpoints).to include(-2) if assistant_indices.length >= 1
    end
  end

  context "continuation call (after a mid-turn dice roll)" do
    before do
      create(:event, scene:, kind: "pc_declaration", pc: aragorn, turn_number: 1,
             payload: { "text" => "I approach the captain." })
      create(:event, scene:, kind: "narration", turn_number: 1,
             payload: { "text" => "He straightens. [[1d20+5 — Aragorn Insight on the captain]]" })
      create(:event, scene:, kind: "dice_roll", pc: aragorn, turn_number: 1,
             payload: { "expression" => "1d20+5", "result" => 17, "reason" => "Insight on the captain" })
    end

    subject(:prompt) do
      described_class.continuation(scene:, latest_roll: scene.events.where(kind: "dice_roll").last)
    end

    it "ends with a user message containing only the roll result" do
      expect(prompt.messages.last[:role]).to eq("user")
      expect(prompt.messages.last[:content]).to include("Aragorn rolled 1d20+5 = 17")
      expect(prompt.messages.last[:content]).not_to include("approach the captain")
    end

    it "includes the partial narration as the preceding assistant message" do
      assistant_idx = prompt.messages.rindex { _1[:role] == "assistant" }
      expect(prompt.messages[assistant_idx][:content]).to include("He straightens.")
    end
  end

  describe "asymmetry-NOT-protected (narrator prompt is DM-side)" do
    # PromptBuilder *should* include secrets — this is not a leak, it's the contract.
    # The asymmetry meta-spec covers Player VMs and Play components, not PromptBuilder.
    it "includes scene_secret content in scene block" do
      prompt = described_class.framing(scene:)
      expect(prompt.system[2][:text]).to include("2 skeletons")
    end
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `bundle exec rspec spec/lib/narrator/prompt_builder_spec.rb`
Expected: FAIL — class methods don't exist with those signatures.

- [ ] **Step 3: Rewrite the prompt builder**

Replace `app/lib/narrator/prompt_builder.rb` entirely:

```ruby
module Narrator
  class PromptBuilder
    STOP_SEQUENCES = [ "]]" ].freeze

    def self.framing(scene:)
      new(scene:, kind: :framing).build
    end

    def self.resolution(scene:, current_turn_declarations:)
      new(scene:, kind: :resolution, current_turn_declarations: current_turn_declarations).build
    end

    def self.continuation(scene:, latest_roll:)
      new(scene:, kind: :continuation, latest_roll: latest_roll).build
    end

    def initialize(scene:, kind:, current_turn_declarations: [], latest_roll: nil)
      @scene = scene
      @kind = kind
      @current_turn_declarations = current_turn_declarations
      @latest_roll = latest_roll
    end

    def build
      Narrator::Prompt.new(
        system: build_system_blocks,
        messages: build_messages,
        cache_breakpoints: build_cache_breakpoints,
        stop_sequences: STOP_SEQUENCES
      )
    end

    private

    attr_reader :scene, :kind, :current_turn_declarations, :latest_roll

    def campaign = scene.campaign

    # ── System blocks ────────────────────────────────────────────────

    def build_system_blocks
      [
        { type: "text", text: discipline_text },
        { type: "text", text: campaign_text },
        { type: "text", text: scene_text }
      ]
    end

    def discipline_text
      template = Narrator::SystemPrompt.text
      template
        .gsub("{pc_names}",        campaign_vm.pcs.map(&:name).join(", ").presence || "none")
        .gsub("{companion_names}", campaign_vm.companions.map(&:name).join(", ").presence || "none")
    end

    def campaign_text
      [
        "# Campaign",
        "Name: #{campaign_vm.name}",
        campaign_vm.description.to_s,
        "",
        "# Party",
        party_md,
        "",
        "# Factions",
        campaign_vm.factions.map { faction_md(_1) }.join("\n\n").presence || "(none)",
        "",
        "# NPCs",
        campaign_vm.npcs.map { npc_md(_1) }.join("\n\n").presence || "(none)"
      ].join("\n")
    end

    def party_md
      lines = []
      lines << "## PCs"
      campaign_vm.pcs.each { lines << pc_md(_1) }
      lines << "## Companions"
      campaign_vm.companions.each { lines << pc_md(_1) }
      lines.join("\n")
    end

    def pc_md(pc)
      parts = [ "- **#{pc.name}** (#{pc.role}) — #{pc.class_name} #{pc.level}, #{pc.pronouns}" ]
      parts << "  Notes: #{pc.notes}" if pc.notes.present?
      parts.join("\n")
    end

    def faction_md(f)
      lines = [ "## #{f.name}", f.public_description.to_s ]
      f.secrets.each { lines << "- _SECRET (#{_1.label}):_ #{_1.content}" }
      lines.join("\n")
    end

    def npc_md(n)
      lines = [ "## #{n.name}" ]
      lines << "Location: #{n.location}" if n.location.present?
      lines << n.public_description.to_s
      n.secrets.each { lines << "- _SECRET (#{_1.label}):_ #{_1.content}" }
      lines.join("\n")
    end

    def scene_text
      lines = [
        "# Current scene",
        "Title: #{scene_vm.title}",
        scene_vm.summary.to_s
      ]
      if scene_vm.scene_secrets.any?
        lines << ""
        lines << "## DM-only scene notes"
        scene_vm.scene_secrets.each { lines << "- **#{_1.label}**: #{_1.content}" }
      end
      lines.join("\n")
    end

    # ── Messages ─────────────────────────────────────────────────────

    def build_messages
      msgs = completed_turn_messages
      msgs += partial_turn_messages
      msgs << current_user_message
      msgs.compact
    end

    def completed_turns
      events = scene.events.where(kind: %w[pc_declaration dice_roll narration]).order(:turn_number, :occurred_at, :id)
      events.group_by(&:turn_number).select { |_, evs| evs.any? { _1.kind == "narration" } && handoff?(evs.select { _1.kind == "narration" }.last) }
    end

    def completed_turn_messages
      completed_turns.flat_map do |turn_n, evs|
        [
          { role: "user",      content: user_content_for_turn(turn_n, evs) },
          { role: "assistant", content: assistant_content_for_turn(evs) }
        ]
      end
    end

    def partial_turn_messages
      # Only relevant for continuation kind: include partial narration as last assistant message
      return [] unless kind == :continuation
      partial = scene.events.where(kind: "narration").order(:turn_number, :occurred_at, :id).last
      return [] unless partial
      [ { role: "assistant", content: partial.payload["text"].to_s } ]
    end

    def current_user_message
      case kind
      when :framing
        { role: "user", content: "[Scene start] What does #{main_character_name} do?" }
      when :resolution
        { role: "user", content: "[Turn #{turn_number}]\n" + format_declarations(current_turn_declarations) }
      when :continuation
        roll = latest_roll
        pc_name = roll.pc&.name || "Unknown PC"
        line = "#{pc_name} rolled #{roll.payload['expression']} = #{roll.payload['result']}"
        line += " (#{roll.payload['reason']})" if roll.payload["reason"].present?
        { role: "user", content: line + "." }
      end
    end

    def user_content_for_turn(turn_n, evs)
      declarations = evs.select { _1.kind == "pc_declaration" }
      rolls        = evs.select { _1.kind == "dice_roll" }
      lines = [ "[Turn #{turn_n}]" ]
      declarations.each { lines << "#{_1.pc.name} declares: #{_1.payload['text']}" }
      rolls.each do |r|
        line = "#{r.pc&.name || 'Unknown PC'} rolled #{r.payload['expression']} = #{r.payload['result']}"
        line += " (#{r.payload['reason']})" if r.payload["reason"].present?
        lines << line + "."
      end
      lines.join("\n")
    end

    def assistant_content_for_turn(evs)
      evs.select { _1.kind == "narration" }.map { _1.payload["text"].to_s }.join("\n\n")
    end

    def format_declarations(decls)
      decls.map { "#{_1[:pc].name} declares: #{_1[:text]}" }.join("\n")
    end

    def handoff?(narration_event)
      narration_event.payload["text"].to_s =~ /\?\s*\z/
    end

    def turn_number
      Player::SceneStateViewModel.new(scene).current_turn_number
    end

    def main_character_name
      campaign.main_character&.name || "the party"
    end

    # ── Cache breakpoints ────────────────────────────────────────────

    def build_cache_breakpoints
      bps = [ 0, 1, 2 ]
      assistant_count = build_messages.count { _1[:role] == "assistant" }
      bps << -2 if assistant_count >= 2
      bps
    end

    # ── View models ──────────────────────────────────────────────────

    def campaign_vm = @campaign_vm ||= Narrator::CampaignViewModel.new(campaign)
    def scene_vm    = @scene_vm    ||= Narrator::SceneViewModel.new(scene)
  end
end
```

- [ ] **Step 4: Run spec to green**

Run: `bundle exec rspec spec/lib/narrator/prompt_builder_spec.rb`
Expected: green.

- [ ] **Step 5: Commit**

```bash
git add app/lib/narrator/prompt_builder.rb spec/lib/narrator/prompt_builder_spec.rb
git commit -m "Narrator::PromptBuilder: conversation-shaped rewrite (framing/resolution/continuation)"
```

---

### Task 16: Narrator::CollectionPrompt — templated agent prompts

**Files:**
- Create: `app/lib/narrator/collection_prompt.rb`
- Create: `spec/lib/narrator/collection_prompt_spec.rb`

- [ ] **Step 1: Write the failing spec**

```ruby
require "rails_helper"

RSpec.describe Narrator::CollectionPrompt do
  describe ".companion_check" do
    it "returns a non-empty string mentioning all companion names" do
      result = described_class.companion_check([ "Caine", "Fred", "Patric" ])
      %w[Caine Fred Patric].each { expect(result).to include(_1) }
    end
  end

  describe ".next_pc" do
    it "for one name uses 'And X?' or 'What about X?'" do
      result = described_class.next_pc([ "Patric" ])
      expect(result).to satisfy { |s| s.include?("Patric") }
    end

    it "for multiple names lists them" do
      result = described_class.next_pc([ "Caine", "Patric" ])
      expect(result).to include("Caine").and include("Patric")
    end
  end

  describe ".short_circuit_decline" do
    it "lists remaining PCs and reminds about 'they hold'" do
      result = described_class.short_circuit_decline([ "Caine", "Patric" ])
      expect(result).to include("Caine").and include("Patric").and include("hold")
    end
  end

  describe ".no_focus_no_main" do
    it "asks for clarification" do
      expect(described_class.no_focus_no_main).to include("which PC")
    end
  end

  describe ".unknown_pc" do
    it "names the unknown" do
      expect(described_class.unknown_pc("Boromir")).to include("Boromir")
    end
  end

  describe ".format_names" do
    it "oxford-comma joins three" do
      expect(described_class.send(:format_names, %w[A B C])).to eq("A, B, and C")
    end

    it "joins two with 'and'" do
      expect(described_class.send(:format_names, %w[A B])).to eq("A and B")
    end

    it "passes one through" do
      expect(described_class.send(:format_names, %w[A])).to eq("A")
    end
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `bundle exec rspec spec/lib/narrator/collection_prompt_spec.rb`
Expected: FAIL — module undefined.

- [ ] **Step 3: Implement**

Create `app/lib/narrator/collection_prompt.rb`:

```ruby
module Narrator
  module CollectionPrompt
    module_function

    def companion_check(names)
      [
        "Anything for #{format_names(names)}, or shall I run them?",
        "What about #{format_names(names)}?",
        "Anything from #{format_names(names)}?"
      ].sample
    end

    def next_pc(names)
      case names.size
      when 1 then [ "And #{names.first}?", "What about #{names.first}?" ].sample
      else        [ "What about #{format_names(names)}?", "And #{format_names(names)}?" ].sample
      end
    end

    def short_circuit_decline(names)
      "Wait — I still need #{format_names(names)}. Even 'they hold' is fine."
    end

    def no_focus_no_main = "For which PC?"

    def unknown_pc(name) = "I don't see #{name} in the party."

    def format_names(names)
      case names.size
      when 0 then ""
      when 1 then names.first
      when 2 then "#{names.first} and #{names.last}"
      else        "#{names[0..-2].join(', ')}, and #{names.last}"
      end
    end
  end
end
```

- [ ] **Step 4: Run to green**

Run: `bundle exec rspec spec/lib/narrator/collection_prompt_spec.rb`
Expected: green.

- [ ] **Step 5: Commit**

```bash
git add app/lib/narrator/collection_prompt.rb spec/lib/narrator/collection_prompt_spec.rb
git commit -m "Add Narrator::CollectionPrompt templated agent prompts"
```

---

### Task 17: Narrator::DeclarationParser

**Files:**
- Create: `app/lib/narrator/declaration_parser.rb`
- Create: `app/lib/narrator/declaration_parser/success.rb`
- Create: `app/lib/narrator/declaration_parser/failure.rb`
- Create: `app/lib/narrator/declaration_parser/dice_roll.rb`
- Create: `spec/lib/narrator/declaration_parser_spec.rb`

- [ ] **Step 1: Write the failing spec**

```ruby
require "rails_helper"

RSpec.describe Narrator::DeclarationParser do
  let(:campaign) { create(:campaign) }
  let!(:aragorn) { create(:player_character, campaign:, name: "Aragorn", role: "pc") }
  let!(:caine)   { create(:player_character, campaign:, name: "Caine",   role: "companion") }
  let!(:fred)    { create(:player_character, campaign:, name: "Fred",    role: "companion") }
  let!(:patric)  { create(:player_character, campaign:, name: "Patric",  role: "companion") }
  before         { campaign.update!(main_character: aragorn) }
  let(:scene)    { create(:scene, campaign:) }

  def parse(text, focus: nil, undeclared_pcs: [ aragorn ], undeclared_companions: [ caine, fred, patric ])
    described_class.call(
      text: text,
      campaign: campaign,
      focus_pc: focus,
      undeclared_pcs: undeclared_pcs,
      undeclared_companions: undeclared_companions
    )
  end

  context "dice-only input" do
    it "returns a DiceRoll with main PC as default" do
      result = parse("1d20+3")
      expect(result).to be_a(Narrator::DeclarationParser::DiceRoll)
      expect(result.expression).to eq("1d20+3")
      expect(result.pc).to eq(aragorn)
    end
  end

  context "unattributed declaration with main PC set" do
    it "routes to main PC" do
      result = parse("I push the door open")
      expect(result).to be_a(Narrator::DeclarationParser::Success)
      expect(result.declarations).to eq([ { pc: aragorn, text: "I push the door open" } ])
    end
  end

  context "explicit name" do
    it "attributes to the named PC" do
      result = parse("Caine listens at the door")
      expect(result.declarations).to eq([ { pc: caine, text: "Caine listens at the door" } ])
    end

    it "splits multiple names with sentence delimiters" do
      result = parse("Aragorn looks. Caine listens.")
      pcs = result.declarations.map { _1[:pc] }
      expect(pcs).to contain_exactly(aragorn, caine)
    end
  end

  context "group/anaphoric words" do
    it "attributes 'the rest' to all undeclared companions" do
      result = parse("The rest hang back",
                     undeclared_pcs: [], undeclared_companions: [ caine, fred, patric ])
      pcs = result.declarations.map { _1[:pc] }
      expect(pcs).to contain_exactly(caine, fred, patric)
    end

    it "attributes 'they' similarly" do
      result = parse("They follow Aragorn",
                     undeclared_pcs: [], undeclared_companions: [ caine, fred, patric ])
      expect(result.declarations.size).to eq(3)
    end
  end

  context "unknown PC" do
    it "fails with unknown_pc message" do
      result = parse("Boromir charges in")
      expect(result).to be_a(Narrator::DeclarationParser::Failure)
      expect(result.reason).to include("Boromir")
    end
  end

  context "no focus, no main, unattributed" do
    it "fails with no_focus_no_main" do
      campaign.update!(main_character: nil)
      result = parse("opens the door", focus: nil, undeclared_pcs: [ aragorn ], undeclared_companions: [])
      expect(result).to be_a(Narrator::DeclarationParser::Failure)
      expect(result.reason).to include("which PC")
    end
  end

  context "focus override" do
    it "routes to focus PC when no name and main set" do
      result = parse("listens", focus: caine,
                     undeclared_pcs: [], undeclared_companions: [ caine, fred, patric ])
      expect(result.declarations).to eq([ { pc: caine, text: "listens" } ])
    end
  end

  context "short-circuit attempt" do
    it "fails when PCs undeclared and player says 'resolve'" do
      result = parse("resolve", undeclared_pcs: [ aragorn ])
      expect(result).to be_a(Narrator::DeclarationParser::Failure)
      expect(result.reason).to include("Aragorn")
    end
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `bundle exec rspec spec/lib/narrator/declaration_parser_spec.rb`
Expected: FAIL.

- [ ] **Step 3: Create the result types (one file per Zeitwerk convention)**

`app/lib/narrator/declaration_parser/success.rb`:

```ruby
module Narrator
  class DeclarationParser
    Success = Data.define(:declarations)
  end
end
```

`app/lib/narrator/declaration_parser/failure.rb`:

```ruby
module Narrator
  class DeclarationParser
    Failure = Data.define(:reason)
  end
end
```

`app/lib/narrator/declaration_parser/dice_roll.rb`:

```ruby
module Narrator
  class DeclarationParser
    DiceRoll = Data.define(:expression, :pc)
  end
end
```

- [ ] **Step 4: Implement the parser**

`app/lib/narrator/declaration_parser.rb`:

```ruby
module Narrator
  class DeclarationParser
    GROUP_RE     = /\b(the rest|the others|the party|everyone else|they|both)\b/i
    SHORTCUT_RE  = /\A\s*(resolve|go|next|done|nothing)\s*[.!]?\s*\z/i
    DICE_RE      = /\A\s*\d*d\d+([+\-]\d+)?\s*\z/i

    def self.call(**kwargs) = new(**kwargs).call

    def initialize(text:, campaign:, focus_pc: nil, undeclared_pcs: [], undeclared_companions: [])
      @text = text.to_s
      @campaign = campaign
      @focus_pc = focus_pc
      @undeclared_pcs = undeclared_pcs
      @undeclared_companions = undeclared_companions
    end

    def call
      return DiceRoll.new(expression: text.strip, pc: dice_default_pc) if text =~ DICE_RE
      return shortcut_failure if text =~ SHORTCUT_RE && @undeclared_pcs.any?
      return Failure.new(reason: CollectionPrompt.short_circuit_decline(@undeclared_pcs.map(&:name))) if text =~ SHORTCUT_RE

      named = matched_names
      unknown = unknown_names
      return Failure.new(reason: CollectionPrompt.unknown_pc(unknown.first)) if unknown.any?
      return build_named_declarations(named) if named.any?

      if text =~ GROUP_RE && @undeclared_companions.any?
        decls = (@undeclared_pcs + @undeclared_companions).map { { pc: _1, text: text } }
        return Success.new(declarations: decls)
      end

      return Success.new(declarations: [ { pc: default_target, text: text } ]) if default_target
      Failure.new(reason: CollectionPrompt.no_focus_no_main)
    end

    private

    attr_reader :text

    def all_party = @all_party ||= @campaign.player_characters.to_a

    def matched_names
      all_party.select { name_present?(_1.name) }
    end

    def unknown_names
      # Look for capitalized whole-word tokens that aren't a party member's name
      caps = text.scan(/\b[A-Z][a-z]+\b/)
      caps.reject { |w| all_party.any? { _1.name.casecmp(w).zero? } || %w[I The And A But Or So Then].include?(w) }
    end

    def name_present?(name)
      text =~ /\b#{Regexp.escape(name)}\b/i
    end

    def build_named_declarations(pcs)
      # Simple per-sentence split: if multiple names AND multiple sentences, attribute per sentence
      sentences = text.split(/(?<=[.!?])\s+/)
      if pcs.size > 1 && sentences.size > 1
        decls = sentences.flat_map do |s|
          matched = pcs.select { |p| s =~ /\b#{Regexp.escape(p.name)}\b/i }
          matched.map { { pc: _1, text: s.strip } }
        end
        return Success.new(declarations: decls.uniq { _1[:pc].id })
      end
      Success.new(declarations: pcs.map { { pc: _1, text: text } })
    end

    def default_target = @focus_pc || @campaign.main_character

    def dice_default_pc = @focus_pc || @campaign.main_character

    def shortcut_failure
      Failure.new(reason: CollectionPrompt.short_circuit_decline(@undeclared_pcs.map(&:name)))
    end
  end
end
```

- [ ] **Step 5: Run to green**

Run: `bundle exec rspec spec/lib/narrator/declaration_parser_spec.rb`
Expected: green.

- [ ] **Step 6: Commit**

```bash
git add app/lib/narrator/declaration_parser*.rb spec/lib/narrator/declaration_parser_spec.rb
git commit -m "Add Narrator::DeclarationParser (name-based attribution with group/focus/main fallback)"
```

---

## Phase 6 — Turn machine controllers

### Task 18: Play::PcDeclarationsController

**Files:**
- Create: `app/controllers/play/pc_declarations_controller.rb`
- Modify: `config/routes/play.rb` — add `resources :pc_declarations, only: [:create]` nested under scenes
- Create: `spec/requests/play/pc_declarations_spec.rb`

- [ ] **Step 1: Write the failing request spec**

```ruby
require "rails_helper"

RSpec.describe "Play::PcDeclarations", type: :request do
  include ActiveJob::TestHelper

  let(:user)     { create(:user) }
  let(:campaign) { create(:campaign, user:) }
  let!(:aragorn) { create(:player_character, campaign:, name: "Aragorn", role: "pc") }
  let!(:caine)   { create(:player_character, campaign:, name: "Caine",   role: "companion") }
  before         { campaign.update!(main_character: aragorn) }
  let(:scene)    { create(:scene, campaign:) }

  before { sign_in user }

  describe "POST /play/scenes/:id/pc_declarations" do
    it "creates a pc_declaration event attributed to the main PC for unattributed text" do
      expect {
        post play_scene_pc_declarations_path(scene), params: { text: "I push the door open." }
      }.to change { scene.events.where(kind: "pc_declaration").count }.by(1)

      decl = scene.events.where(kind: "pc_declaration").last
      expect(decl.pc).to eq(aragorn)
      expect(decl.payload["text"]).to eq("I push the door open.")
    end

    it "creates a dice_roll event when input matches dice expression" do
      expect {
        post play_scene_pc_declarations_path(scene), params: { text: "1d20+3" }
      }.to change { scene.events.where(kind: "dice_roll").count }.by(1)
    end

    it "creates a gm_collection_prompt and re-prompts on unknown PC" do
      expect {
        post play_scene_pc_declarations_path(scene), params: { text: "Boromir charges" }
      }.to change { scene.events.where(kind: "gm_collection_prompt").count }.by(1)

      prompt = scene.events.where(kind: "gm_collection_prompt").last
      expect(prompt.payload["text"]).to include("Boromir")
    end

    it "enqueues a NarrationJob when all PCs declared and companion check satisfied (no companions)" do
      campaign.player_characters.companions.destroy_all
      expect {
        post play_scene_pc_declarations_path(scene), params: { text: "I look around." }
      }.to have_enqueued_job(NarrationJob).with(hash_including(trigger: "resolution"))
    end

    it "emits a companion_check gm_collection_prompt after main PC declares (companions exist)" do
      expect {
        post play_scene_pc_declarations_path(scene), params: { text: "I look around." }
      }.to change { scene.events.where(kind: "gm_collection_prompt", payload: { "kind" => "companion_check" }).count }.by(1)
    end
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `bundle exec rspec spec/requests/play/pc_declarations_spec.rb`
Expected: FAIL — route undefined.

- [ ] **Step 3: Add the route**

In `config/routes/play.rb`, inside `resources :scenes` (alongside `resources :dice_rolls`):

```ruby
      resources :pc_declarations, only: [ :create ]
```

Remove the old `resources :narrations, only: [:create]` and `resources :oracle_queries` lines (if present).

- [ ] **Step 4: Write the controller**

```ruby
module Play
  class PcDeclarationsController < ::ApplicationController
    before_action :authenticate_user!

    def create
      scene = current_user.campaigns.find_by!(id: scene_record.campaign_id) && scene_record
      state = Player::SceneStateViewModel.new(scene)

      result = Narrator::DeclarationParser.call(
        text: params.require(:text),
        campaign: scene.campaign,
        focus_pc: focus_pc(state),
        undeclared_pcs: state.undeclared_pcs_this_turn,
        undeclared_companions: state.undeclared_companions_this_turn
      )

      handle_result(scene, state, result)

      head :no_content
    end

    private

    def scene_record
      @scene_record ||= Scene.find(params[:scene_id]).tap do |s|
        raise ActiveRecord::RecordNotFound unless current_user.campaigns.exists?(id: s.campaign_id)
      end
    end

    def focus_pc(state)
      # If the most recent gm_collection_prompt narrowed to a single PC, use that PC as focus
      last_prompt = scene_record.events.where(kind: "gm_collection_prompt").order(:occurred_at).last
      return nil unless last_prompt
      pc_id = last_prompt.payload["focus_pc_id"]
      pc_id && scene_record.campaign.player_characters.find_by(id: pc_id)
    end

    def handle_result(scene, state, result)
      case result
      when Narrator::DeclarationParser::Success
        create_declarations(scene, state, result.declarations)
        advance_turn(scene)
      when Narrator::DeclarationParser::DiceRoll
        DiceRollCreator.call(scene:, pc: result.pc, expression: result.expression, reason: nil, turn_number: state.current_turn_number)
        # No NarrationJob — dice rolls during collection don't trigger resolution
      when Narrator::DeclarationParser::Failure
        create_prompt(scene, state, text: result.reason)
      end
    end

    def create_declarations(scene, state, declarations)
      Event.transaction do
        declarations.each do |d|
          scene.events.create!(
            kind: "pc_declaration",
            pc: d[:pc],
            turn_number: state.current_turn_number,
            payload: { "text" => d[:text] }
          )
        end
      end
    end

    def advance_turn(scene)
      state = Player::SceneStateViewModel.new(scene)
      undeclared_pcs = state.undeclared_pcs_this_turn

      if undeclared_pcs.any?
        create_prompt(scene, state,
                      text: Narrator::CollectionPrompt.next_pc(undeclared_pcs.map(&:name)),
                      focus_pc_id: undeclared_pcs.first.id)
        return
      end

      if !state.companion_prompt_offered?
        companions = scene.campaign.player_characters.companions.order(:name)
        create_prompt(scene, state,
                      text: Narrator::CollectionPrompt.companion_check(companions.map(&:name)),
                      kind: "companion_check")
        return
      end

      enqueue_resolution(scene, state.current_turn_number)
    end

    def create_prompt(scene, state, text:, focus_pc_id: nil, kind: "general")
      scene.events.create!(
        kind: "gm_collection_prompt",
        turn_number: state.current_turn_number,
        payload: { "text" => text, "focus_pc_id" => focus_pc_id, "kind" => kind }.compact
      )
    end

    def enqueue_resolution(scene, turn_number)
      narration = scene.events.create!(
        kind: "narration",
        turn_number: turn_number,
        payload: { "text" => "", "status" => "streaming", "trigger" => "resolution" }
      )
      NarrationJob.perform_later(scene_id: scene.id, narration_event_id: narration.id, trigger: "resolution")
    end
  end
end
```

(`DiceRollCreator` is a new tiny extraction — defer the actual class to Task 21 if needed; for now this controller path won't fire in the Phase 9.1 critical-path tests except for the dice-only declaration.)

- [ ] **Step 5: Extract a DiceRollCreator shared service**

Create `app/services/dice_roll_creator.rb`:

```ruby
class DiceRollCreator
  def self.call(scene:, pc:, expression:, reason: nil, turn_number:)
    roll = ::Dice::Roll.call(expression)
    scene.events.create!(
      kind: "dice_roll",
      pc: pc,
      turn_number: turn_number,
      payload: {
        "expression" => expression,
        "result"     => roll.total,
        "breakdown"  => roll.breakdown,
        "reason"     => reason
      }.compact
    )
  end
end
```

- [ ] **Step 6: Run the spec**

Run: `bundle exec rspec spec/requests/play/pc_declarations_spec.rb`
Expected: green.

- [ ] **Step 7: Commit**

```bash
git add app/controllers/play/pc_declarations_controller.rb \
        app/services/dice_roll_creator.rb \
        config/routes/play.rb \
        spec/requests/play/pc_declarations_spec.rb
git commit -m "Play::PcDeclarationsController: parse → events → trigger resolution"
```

---

### Task 19: Play::ScenesController — auto-frame on first load

**Files:**
- Modify: `app/controllers/play/scenes_controller.rb` — enqueue framing NarrationJob when scene loads with zero events
- Modify: `spec/requests/play/scenes_spec.rb` (or wherever the play action spec lives)

- [ ] **Step 1: Write failing spec**

Append to the play scenes request spec:

```ruby
describe "framing trigger" do
  include ActiveJob::TestHelper

  it "enqueues a framing NarrationJob when scene has zero events" do
    user     = create(:user)
    campaign = create(:campaign, user:)
    create(:player_character, campaign:, name: "Aragorn", role: "pc").tap { campaign.update!(main_character: _1) }
    scene = create(:scene, campaign:)
    sign_in user
    expect {
      get play_scene_path(scene)
    }.to have_enqueued_job(NarrationJob).with(hash_including(trigger: "framing"))
  end

  it "does not enqueue framing when events exist" do
    scene = create(:scene)
    create(:event, scene:, kind: "narration", payload: { "text" => "What do you do?" })
    sign_in scene.campaign.user
    expect {
      get play_scene_path(scene)
    }.not_to have_enqueued_job(NarrationJob)
  end
end
```

- [ ] **Step 2: Run to verify failure**

Expected: FAIL — controller doesn't enqueue.

- [ ] **Step 3: Update Play::ScenesController#play**

Add to the `play` action (after loading `@scene`):

```ruby
if @scene.events.empty?
  narration = @scene.events.create!(
    kind: "narration",
    turn_number: 1,
    payload: { "text" => "", "status" => "streaming", "trigger" => "framing" }
  )
  NarrationJob.perform_later(scene_id: @scene.id, narration_event_id: narration.id, trigger: "framing")
end
```

- [ ] **Step 4: Run spec to green**

Expected: green.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/play/scenes_controller.rb spec/requests/play/scenes_spec.rb
git commit -m "Play::ScenesController: auto-frame scene on first load (zero events)"
```

---

### Task 20: Play::DiceRollsController — trigger continuation after roll

**Files:**
- Modify: `app/controllers/play/dice_rolls_controller.rb` — after creating dice_roll, enqueue continuation NarrationJob if scene is in awaiting_roll phase
- Modify: `spec/requests/play/dice_rolls_spec.rb`

- [ ] **Step 1: Add failing spec**

Append to existing dice_rolls request spec:

```ruby
describe "continuation trigger" do
  include ActiveJob::TestHelper

  let(:user)     { create(:user) }
  let(:campaign) { create(:campaign, user:) }
  let!(:aragorn) { create(:player_character, campaign:, name: "Aragorn", role: "pc").tap { campaign.update!(main_character: _1) } }
  let(:scene)    { create(:scene, campaign:) }

  before do
    sign_in user
    # Set up awaiting_roll state: a narration ending with an open chip
    create(:event, scene:, kind: "narration", turn_number: 1,
           payload: { "text" => "The door creaks. [[1d20+3 — Aragorn Strength" })
  end

  it "enqueues a continuation NarrationJob after the roll" do
    expect {
      post play_scene_dice_rolls_path(scene), params: { expression: "1d20+3", pc_id: aragorn.id, reason: "Strength" }
    }.to have_enqueued_job(NarrationJob).with(hash_including(trigger: "continuation"))
  end
end
```

- [ ] **Step 2: Verify failure**

Run the spec. Expected: FAIL.

- [ ] **Step 3: Update the controller**

In `app/controllers/play/dice_rolls_controller.rb`, after the dice_roll event is created, add:

```ruby
state = Player::SceneStateViewModel.new(@scene)
if state.phase == :awaiting_roll
  narration = @scene.events.create!(
    kind: "narration",
    turn_number: state.current_turn_number,
    payload: { "text" => "", "status" => "streaming", "trigger" => "continuation" }
  )
  NarrationJob.perform_later(scene_id: @scene.id, narration_event_id: narration.id, trigger: "continuation")
end
```

- [ ] **Step 4: Run spec to green**

Expected: green.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/play/dice_rolls_controller.rb spec/requests/play/dice_rolls_spec.rb
git commit -m "Play::DiceRollsController: enqueue continuation NarrationJob when awaiting_roll"
```

---

### Task 21: Remove oracle controller, components, routes, JS

**Files (delete based on verification in Step P.2):**
- Delete: `app/controllers/play/<oracle_controller>.rb`
- Delete: `app/components/play/events/<oracle_event_component>.{rb,html.erb}`
- Delete: `app/components/play/oracle/` directory if present
- Delete: `app/javascript/controllers/<oracle_form_controller>.js` if present
- Delete: `app/services/mythic/` directory if present
- Modify: `config/routes/play.rb` — remove oracle routes
- Modify: `app/javascript/application.js` — remove oracle controller registration
- Delete: corresponding specs

- [ ] **Step 1: Run a grep sweep to find all oracle references**

Run: `grep -rln "oracle" app/ spec/ config/ db/ | grep -v 'docs/'`
Note all files. Delete only the implementation files (not the spec/playtest documents).

- [ ] **Step 2: Delete files identified in Step P.2**

```bash
git rm <each oracle file noted in P.2 and the grep>
```

- [ ] **Step 3: Remove oracle routes from `config/routes/play.rb`**

Remove any `resources :oracle_queries` or similar lines.

- [ ] **Step 4: Remove oracle controller registration from `app/javascript/application.js`**

Remove the `import OracleFormController from ...` and the `application.register("oracle-form", OracleFormController)` lines if present.

- [ ] **Step 5: Run full spec suite to find remaining oracle references**

Run: `bundle exec rspec`
Expected: ANY oracle-related spec failures must be either deleted (if testing the removed code) or updated (if testing related code that referenced the oracle).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "Remove oracle controller, components, routes, JS (oracle dropped from A1)"
```

---

## Phase 7 — NarrationJob rewrite

### Task 22: NarrationJob — trigger discriminator + stop_sequences

**Files:**
- Modify: `app/jobs/narration_job.rb`
- Modify: `spec/jobs/narration_job_spec.rb`

- [ ] **Step 1: Replace the job spec**

Rewrite `spec/jobs/narration_job_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe NarrationJob, type: :job do
  include ActiveJob::TestHelper

  let(:campaign) { create(:campaign) }
  let!(:aragorn) { create(:player_character, campaign:, name: "Aragorn", role: "pc").tap { campaign.update!(main_character: _1) } }
  let(:scene)    { create(:scene, campaign:) }

  before do
    Llm::Providers::Anthropic.reset_client!
    stub_anthropic_streaming(deltas: [ "OK. ", "What do you do?" ])
  end

  describe "framing trigger" do
    it "calls PromptBuilder.framing and persists the streamed text" do
      narration = scene.events.create!(kind: "narration", turn_number: 1,
                                       payload: { "text" => "", "status" => "streaming", "trigger" => "framing" })
      described_class.perform_now(scene_id: scene.id, narration_event_id: narration.id, trigger: "framing")
      expect(narration.reload.payload["text"]).to eq("OK. What do you do?")
      expect(narration.reload.payload["status"]).to eq("complete")
    end
  end

  describe "resolution trigger" do
    before do
      create(:event, scene:, kind: "pc_declaration", pc: aragorn, turn_number: 1,
             payload: { "text" => "I look around." })
    end

    it "calls PromptBuilder.resolution with the turn's declarations" do
      narration = scene.events.create!(kind: "narration", turn_number: 1,
                                       payload: { "text" => "", "status" => "streaming", "trigger" => "resolution" })
      described_class.perform_now(scene_id: scene.id, narration_event_id: narration.id, trigger: "resolution")
      expect(narration.reload.payload["status"]).to eq("complete")
    end
  end

  describe "continuation trigger" do
    before do
      create(:event, scene:, kind: "pc_declaration", pc: aragorn, turn_number: 1, payload: { "text" => "approach" })
      create(:event, scene:, kind: "narration", turn_number: 1,
             payload: { "text" => "He looks up. [[1d20 — Aragorn Insight", "status" => "complete" })
      create(:event, scene:, kind: "dice_roll", pc: aragorn, turn_number: 1,
             payload: { "expression" => "1d20", "result" => 14, "reason" => "Insight" })
    end

    it "calls PromptBuilder.continuation with the latest roll" do
      narration = scene.events.create!(kind: "narration", turn_number: 1,
                                       payload: { "text" => "", "status" => "streaming", "trigger" => "continuation" })
      described_class.perform_now(scene_id: scene.id, narration_event_id: narration.id, trigger: "continuation")
      expect(narration.reload.payload["status"]).to eq("complete")
    end
  end

  describe "errored streams" do
    it "marks the event errored on any exception" do
      allow(Llm::Call).to receive(:execute_streaming).and_raise(StandardError, "boom")
      narration = scene.events.create!(kind: "narration", turn_number: 1,
                                       payload: { "text" => "", "status" => "streaming", "trigger" => "framing" })
      expect {
        described_class.perform_now(scene_id: scene.id, narration_event_id: narration.id, trigger: "framing")
      }.to raise_error(StandardError)
      expect(narration.reload.payload["status"]).to eq("errored")
    end
  end
end
```

- [ ] **Step 2: Run to verify failure**

Expected: FAIL — job doesn't accept the new signature.

- [ ] **Step 3: Rewrite the job**

Replace `app/jobs/narration_job.rb`:

```ruby
class NarrationJob < ApplicationJob
  queue_as :narration

  discard_on ActiveRecord::RecordNotFound, KeyError, Llm::ConfigError

  FLUSH_BYTES_THRESHOLD = 25
  FLUSH_MS_THRESHOLD    = 80

  def perform(scene_id:, narration_event_id:, trigger:)
    scene = Scene.find(scene_id)
    event = scene.events.find(narration_event_id)

    prompt = build_prompt(scene:, trigger:)
    accumulated = +""
    last_flush_at = monotonic_ms
    last_flush_size = 0

    Llm::Call.execute_streaming(prompt: prompt, model: model_for_environment) do |chunk:|
      accumulated << chunk[:text]
      now = monotonic_ms
      if (now - last_flush_at) >= FLUSH_MS_THRESHOLD || (accumulated.size - last_flush_size) >= FLUSH_BYTES_THRESHOLD
        flush!(event, accumulated)
        last_flush_at = now
        last_flush_size = accumulated.size
      end
    end

    flush!(event, accumulated)
    event.update!(payload: event.payload.merge("text" => accumulated, "status" => "complete"))
    broadcast(event)
  rescue StandardError
    event&.update!(payload: event.payload.merge("status" => "errored")) if event
    raise
  end

  private

  def build_prompt(scene:, trigger:)
    case trigger.to_s
    when "framing"
      Narrator::PromptBuilder.framing(scene: scene)
    when "resolution"
      decls = scene.events
                .where(kind: "pc_declaration", turn_number: Player::SceneStateViewModel.new(scene).current_turn_number)
                .order(:occurred_at, :id)
                .map { |e| { pc: e.pc, text: e.payload["text"] } }
      Narrator::PromptBuilder.resolution(scene: scene, current_turn_declarations: decls)
    when "continuation"
      latest_roll = scene.events.where(kind: "dice_roll").order(:occurred_at, :id).last
      Narrator::PromptBuilder.continuation(scene: scene, latest_roll: latest_roll)
    else
      raise KeyError, "Unknown trigger: #{trigger}"
    end
  end

  def model_for_environment
    Rails.application.credentials.dig(:anthropic, :model) || "claude-opus-4-7"
  end

  def flush!(event, text)
    event.update_columns(payload: event.payload.merge("text" => text))
    broadcast(event)
  end

  def broadcast(event)
    Turbo::StreamsChannel.broadcast_replace_to(
      [ event.scene, event.scene.campaign.user ],
      target: ActionView::RecordIdentifier.dom_id(event),
      renderable: Play::Events::NarrationComponent.new(event: event),
      layout: false
    )
  end

  def monotonic_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) * 1000).to_i
end
```

- [ ] **Step 4: Run the spec**

Run: `bundle exec rspec spec/jobs/narration_job_spec.rb`
Expected: green.

- [ ] **Step 5: Commit**

```bash
git add app/jobs/narration_job.rb spec/jobs/narration_job_spec.rb
git commit -m "NarrationJob: trigger-discriminated build (framing/resolution/continuation) with stop sequences"
```

---

## Phase 8 — Play surface UI

### Task 23: Event component registry + new event-kind components

**Files:**
- Modify: `app/components/play/events/component.rb` — update REGISTRY
- Create: `app/components/play/events/pc_declaration_component.{rb,html.erb}`
- Create: `app/components/play/events/gm_collection_prompt_component.{rb,html.erb}`
- Create: matching specs

- [ ] **Step 1: Write the component specs**

Create `spec/components/play/events/pc_declaration_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Play::Events::PcDeclarationComponent, type: :component do
  let(:campaign) { create(:campaign) }
  let(:pc)       { create(:player_character, campaign:, name: "Aragorn") }
  let(:scene)    { create(:scene, campaign:) }
  let(:event)    { create(:event, scene:, pc:, kind: "pc_declaration", payload: { "text" => "I look around." }) }

  it "renders the PC name and text" do
    rendered = render_inline(described_class.new(event: event))
    expect(rendered.to_s).to include("Aragorn")
    expect(rendered.to_s).to include("I look around.")
  end

  describe "asymmetry" do
    before do
      faction = create(:faction, campaign:)
      create(:faction_secret, faction:, content: "hidden")
      npc = create(:npc, campaign:)
      create(:npc_secret, npc:, content: "hidden")
    end

    it "does not leak secrets of related records" do
      rendered = render_inline(described_class.new(event: event))
      expect(rendered.to_s).not_to leak_secrets_of(*FactionSecret.all, *NpcSecret.all)
    end
  end
end
```

Create the same for `GmCollectionPromptComponent` (no `pc`, just text).

- [ ] **Step 2: Run to verify failure**

Expected: FAIL — components undefined.

- [ ] **Step 3: Implement PcDeclarationComponent**

```ruby
# app/components/play/events/pc_declaration_component.rb
module Play
  module Events
    class PcDeclarationComponent < ViewComponent::Base
      def initialize(event:)
        @event = event
      end
      attr_reader :event
      def pc_name = event.pc&.name || "Unknown PC"
      def text    = event.payload["text"]
      def dom_id  = helpers.dom_id(event)
    end
  end
end
```

```erb
<!-- app/components/play/events/pc_declaration_component.html.erb -->
<div id="<%= dom_id %>" class="event event--pc-declaration">
  <span class="event__voice">[<%= pc_name %>]</span>
  <span class="event__text"><%= text %></span>
</div>
```

- [ ] **Step 4: Implement GmCollectionPromptComponent**

```ruby
# app/components/play/events/gm_collection_prompt_component.rb
module Play
  module Events
    class GmCollectionPromptComponent < ViewComponent::Base
      def initialize(event:)
        @event = event
      end
      attr_reader :event
      def text   = event.payload["text"]
      def dom_id = helpers.dom_id(event)
    end
  end
end
```

```erb
<!-- app/components/play/events/gm_collection_prompt_component.html.erb -->
<div id="<%= dom_id %>" class="event event--gm-collection-prompt">
  <span class="event__voice">[DM]</span>
  <span class="event__text event__text--utility"><%= text %></span>
</div>
```

- [ ] **Step 5: Update the registry**

Modify `app/components/play/events/component.rb`:

```ruby
module Play
  module Events
    class Component
      REGISTRY = {
        "narration"             => Play::Events::NarrationComponent,
        "pc_declaration"        => Play::Events::PcDeclarationComponent,
        "gm_collection_prompt"  => Play::Events::GmCollectionPromptComponent,
        "dice_roll"             => Play::Events::DiceRollComponent,
        "scene_transition"      => Play::Events::SceneTransitionComponent
      }.freeze

      def self.for(event) = REGISTRY.fetch(event.kind).new(event: event)
    end
  end
end
```

(Remove oracle entry if it existed.)

- [ ] **Step 6: Run specs**

Run: `bundle exec rspec spec/components/play/events/`
Expected: green.

- [ ] **Step 7: Commit**

```bash
git add app/components/play/events/ spec/components/play/events/
git commit -m "Add PcDeclaration + GmCollectionPrompt event components; update registry"
```

---

### Task 24: NarrationComponent — markdown rendering + dice chip parsing

**Files:**
- Create: `app/lib/narrator/chip_parser.rb` (used by component to detect chips)
- Modify: `app/components/play/events/narration_component.{rb,html.erb}`
- Create: `spec/lib/narrator/chip_parser_spec.rb`
- Modify: `spec/components/play/events/narration_component_spec.rb`

- [ ] **Step 1: Write the chip parser spec**

```ruby
require "rails_helper"

RSpec.describe Narrator::ChipParser do
  describe ".parse" do
    it "extracts a single closed chip" do
      result = described_class.parse("Foo [[1d20+3 — Aragorn Strength]] bar.")
      expect(result.chips).to eq([
        { full: "[[1d20+3 — Aragorn Strength]]", expression: "1d20+3", pc_name: "Aragorn", reason: "Strength" }
      ])
      expect(result.open_chip?).to be(false)
    end

    it "detects an unclosed chip at end of text" do
      result = described_class.parse("He smirks. [[1d20+5 — Caine Insight")
      expect(result.open_chip?).to be(true)
      expect(result.open_chip[:expression]).to eq("1d20+5")
    end

    it "returns no chips for plain text" do
      result = described_class.parse("Just prose.")
      expect(result.chips).to be_empty
      expect(result.open_chip?).to be(false)
    end
  end
end
```

- [ ] **Step 2: Verify failure & implement**

```ruby
# app/lib/narrator/chip_parser.rb
module Narrator
  class ChipParser
    CHIP_RE      = /\[\[(?<expr>\S+)\s*(?:—|--|-)\s*(?<pc>[A-Za-z]+)\s+(?<reason>[^\]]+?)\]\]/
    OPEN_CHIP_RE = /\[\[(?<expr>\S*)\s*(?:—|--|-)?\s*(?<pc>[A-Za-z]*)?\s*(?<reason>[^\]]*?)\z/

    Result = Data.define(:chips, :open_chip) do
      def open_chip? = !open_chip.nil?
    end

    def self.parse(text)
      str = text.to_s
      chips = str.scan(CHIP_RE).map do |expr, pc, reason|
        { full: "[[#{expr} — #{pc} #{reason}]]", expression: expr, pc_name: pc, reason: reason.strip }
      end

      stripped = str.gsub(CHIP_RE, "")
      open = nil
      if (m = stripped.match(OPEN_CHIP_RE)) && m[:expr].to_s.length.positive?
        open = { expression: m[:expr], pc_name: m[:pc].to_s, reason: m[:reason].to_s.strip }
      end

      Result.new(chips: chips, open_chip: open)
    end
  end
end
```

If any spec from Step 1 still fails after this implementation, refine the regexes (the chip syntax is dictated by the LLM via the system prompt, so the model + parser must agree). Do not weaken the test expectations to accommodate parser shortcomings.

- [ ] **Step 3: Run chip parser spec**

Run: `bundle exec rspec spec/lib/narrator/chip_parser_spec.rb`
Expected: green.

- [ ] **Step 4: Update NarrationComponent — render markdown + chips**

Modify `app/components/play/events/narration_component.rb`:

```ruby
module Play
  module Events
    class NarrationComponent < ViewComponent::Base
      def initialize(event:)
        @event = event
      end
      attr_reader :event

      def text       = event.payload["text"].to_s
      def status     = event.payload["status"] || "complete"
      def dom_id     = helpers.dom_id(event)
      def streaming? = status == "streaming"
      def errored?   = status == "errored"

      def rendered_html
        chip_data = Narrator::ChipParser.parse(text)
        # Substitute chips with placeholder tokens, render markdown, then swap tokens back in for HTML buttons
        token_map = {}
        text_with_tokens = text.dup
        chip_data.chips.each_with_index do |chip, i|
          token = "{{chip_#{i}}}"
          token_map[token] = chip
          text_with_tokens.sub!(chip[:full], token)
        end
        html = Commonmarker.to_html(text_with_tokens, options: { render: { unsafe: false } })
        token_map.each do |token, chip|
          html = html.sub(token, chip_button_html(chip))
        end
        html.html_safe
      end

      private

      def chip_button_html(chip)
        %(<button class="dice-chip" data-controller="dice-chip" ) +
          %(data-dice-chip-expression-value="#{ERB::Util.html_escape(chip[:expression])}" ) +
          %(data-dice-chip-pc-name-value="#{ERB::Util.html_escape(chip[:pc_name])}" ) +
          %(data-dice-chip-reason-value="#{ERB::Util.html_escape(chip[:reason])}" ) +
          %(data-action="click->dice-chip#roll">) +
          %(🎲 #{ERB::Util.html_escape(chip[:expression])} — #{ERB::Util.html_escape(chip[:pc_name])} #{ERB::Util.html_escape(chip[:reason])}) +
          %(</button>)
      end
    end
  end
end
```

Modify the template `app/components/play/events/narration_component.html.erb`:

```erb
<div id="<%= dom_id %>" class="event event--narration <%= 'streaming' if streaming? %> <%= 'errored' if errored? %>">
  <span class="event__voice">[DM]</span>
  <div class="event__text"><%= rendered_html %></div>
</div>
```

- [ ] **Step 5: Update the component spec**

Add tests for markdown + chips:

```ruby
describe "markdown rendering" do
  it "renders **bold** as <strong>" do
    event = create(:event, kind: "narration", payload: { "text" => "He **slams** the door.", "status" => "complete" })
    rendered = render_inline(described_class.new(event: event))
    expect(rendered.to_s).to include("<strong>slams</strong>")
  end
end

describe "dice chips" do
  it "renders [[…]] as a clickable button" do
    event = create(:event, kind: "narration", payload: { "text" => "Roll [[1d20+3 — Aragorn Strength]] now.", "status" => "complete" })
    rendered = render_inline(described_class.new(event: event))
    expect(rendered.to_s).to include('class="dice-chip"')
    expect(rendered.to_s).to include("1d20+3")
  end
end
```

- [ ] **Step 6: Run specs**

Run: `bundle exec rspec spec/components/play/events/narration_component_spec.rb`
Expected: green.

- [ ] **Step 7: Commit**

```bash
git add app/lib/narrator/chip_parser.rb \
        app/components/play/events/narration_component.rb \
        app/components/play/events/narration_component.html.erb \
        spec/lib/narrator/chip_parser_spec.rb \
        spec/components/play/events/narration_component_spec.rb
git commit -m "NarrationComponent: render markdown via commonmarker + parse dice chips into buttons"
```

---

### Task 25: Stimulus controllers — dice chip + chat composer

**Files:**
- Create: `app/javascript/controllers/dice_chip_controller.js`
- Create: `app/javascript/controllers/chat_composer_controller.js`
- Modify: `app/javascript/application.js` — register both

- [ ] **Step 1: Implement dice_chip_controller**

```javascript
// app/javascript/controllers/dice_chip_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { expression: String, pcName: String, reason: String }

  async roll(event) {
    event.preventDefault()
    this.element.disabled = true
    const sceneId = this.element.closest("[data-scene-id]")?.dataset.sceneId
    const csrfToken = document.querySelector('meta[name="csrf-token"]').content
    await fetch(`/play/scenes/${sceneId}/dice_rolls`, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": csrfToken,
        "Accept": "text/vnd.turbo-stream.html"
      },
      body: new URLSearchParams({
        "expression": this.expressionValue,
        "pc_name":    this.pcNameValue,
        "reason":     this.reasonValue
      })
    })
  }
}
```

- [ ] **Step 2: Implement chat_composer_controller**

```javascript
// app/javascript/controllers/chat_composer_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "form"]

  connect() {
    this.inputTarget.addEventListener("keydown", this.#handleKey.bind(this))
  }

  #handleKey(e) {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault()
      this.element.querySelector("form").requestSubmit()
    }
  }
}
```

- [ ] **Step 3: Register both in application.js**

Edit `app/javascript/application.js` to add:

```javascript
import DiceChipController     from "./controllers/dice_chip_controller"
import ChatComposerController from "./controllers/chat_composer_controller"

application.register("dice-chip",     DiceChipController)
application.register("chat-composer", ChatComposerController)
```

- [ ] **Step 4: Smoke-test the bundle compiles**

Run: `bun run build` (verify the script name in `package.json` if it differs)
Expected: success.

- [ ] **Step 5: Commit**

```bash
git add app/javascript/controllers/dice_chip_controller.js \
        app/javascript/controllers/chat_composer_controller.js \
        app/javascript/application.js
git commit -m "Add Stimulus controllers: dice_chip (roll on click) and chat_composer (Enter submits)"
```

---

### Task 26: Play surface UI components — composer, state indicator, roster sidebar

**Files:**
- Create: `app/components/play/composer_component.{rb,html.erb}`
- Create: `app/components/play/state_indicator_component.{rb,html.erb}`
- Create: `app/components/play/roster/sidebar_component.{rb,html.erb}`
- Create: matching component specs with asymmetry assertions

- [ ] **Step 1: Write component specs**

Create `spec/components/play/composer_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Play::ComposerComponent, type: :component do
  let(:scene) { create(:scene) }
  let!(:pc)   { create(:player_character, campaign: scene.campaign, name: "Aragorn", role: "pc").tap { scene.campaign.update!(main_character: _1) } }

  it "renders a textarea for declarations" do
    rendered = render_inline(described_class.new(scene: scene))
    expect(rendered.to_s).to include("<textarea")
    expect(rendered.to_s).to include("Type your action")
  end

  it "disables the input when phase is awaiting_roll" do
    create(:event, scene:, kind: "narration", turn_number: 1, payload: { "text" => "Roll [[1d20+3 — Aragorn Strength" })
    rendered = render_inline(described_class.new(scene: scene))
    expect(rendered.to_s).to include("disabled")
  end

  describe "asymmetry" do
    before do
      create(:faction_secret, faction: create(:faction, campaign: scene.campaign), content: "hidden")
    end
    it "does not leak secrets of related records" do
      rendered = render_inline(described_class.new(scene: scene))
      expect(rendered.to_s).not_to leak_secrets_of(*FactionSecret.all)
    end
  end
end
```

Similar specs for `StateIndicatorComponent` and `Roster::SidebarComponent` — both must include the `describe "asymmetry"` block with `leak_secrets_of` assertion to satisfy the meta-spec.

- [ ] **Step 2: Implement Play::ComposerComponent**

```ruby
# app/components/play/composer_component.rb
module Play
  class ComposerComponent < ViewComponent::Base
    def initialize(scene:)
      @scene = scene
      @state = Player::SceneStateViewModel.new(scene)
    end
    attr_reader :scene, :state

    def disabled? = !state.composer_enabled?
    def placeholder
      case state.phase
      when :framing       then "Loading scene…"
      when :awaiting_roll then "Roll the dice above to continue."
      when :collecting    then "Type your action…"
      when :idle          then "What's next?"
      else "Narrating…"
      end
    end
  end
end
```

```erb
<!-- app/components/play/composer_component.html.erb -->
<div class="composer" data-controller="chat-composer" data-scene-id="<%= scene.id %>">
  <%= form_with url: play_scene_pc_declarations_path(scene), method: :post, local: false do |f| %>
    <%= f.text_area :text,
                    placeholder: placeholder,
                    disabled: disabled?,
                    rows: 2,
                    data: { chat_composer_target: "input" } %>
    <%= f.submit "Send", disabled: disabled? %>
  <% end %>
</div>
```

- [ ] **Step 3: Implement Play::StateIndicatorComponent**

```ruby
# app/components/play/state_indicator_component.rb
module Play
  class StateIndicatorComponent < ViewComponent::Base
    def initialize(scene:)
      @scene = scene
      @state = Player::SceneStateViewModel.new(scene)
    end
    attr_reader :scene, :state

    def render? = state.phase == :collecting && (state.undeclared_pcs_this_turn.any? || !state.companion_prompt_offered?)

    def message
      if state.undeclared_pcs_this_turn.any?
        "Waiting on: #{state.undeclared_pcs_this_turn.map(&:name).join(', ')}"
      else
        names = state.undeclared_companions_this_turn.map(&:name).join(", ")
        "Waiting on companion check — declare for #{names} or say 'go'"
      end
    end
  end
end
```

```erb
<!-- app/components/play/state_indicator_component.html.erb -->
<% if render? %>
  <div class="state-indicator"><%= message %></div>
<% end %>
```

- [ ] **Step 4: Implement Play::Roster::SidebarComponent**

```ruby
# app/components/play/roster/sidebar_component.rb
module Play
  module Roster
    class SidebarComponent < ViewComponent::Base
      def initialize(scene:)
        @scene = scene
        @state = Player::SceneStateViewModel.new(scene)
      end
      attr_reader :scene, :state

      def pcs        = scene.campaign.player_characters.pcs.order(:name).map { Player::PlayerCharacterViewModel.new(_1) }
      def companions = scene.campaign.player_characters.companions.order(:name).map { Player::PlayerCharacterViewModel.new(_1) }
      def main_id    = scene.campaign.main_character_id
      def declared_ids = state.declared_this_turn.map(&:id)
    end
  end
end
```

```erb
<!-- app/components/play/roster/sidebar_component.html.erb -->
<aside class="roster">
  <h2>Party</h2>
  <section class="roster__section">
    <h3>PCs</h3>
    <% pcs.each do |pc| %>
      <div class="roster__pc">
        <strong><%= pc.name %></strong> <% if pc.id == main_id %>★<% end %>
        <span class="roster__meta"><%= pc.class_name %> <%= pc.level %></span>
        <span class="roster__status"><%= declared_ids.include?(pc.id) ? "✓ declared" : "—" %></span>
      </div>
    <% end %>
  </section>
  <section class="roster__section">
    <h3>Companions</h3>
    <% companions.each do |pc| %>
      <div class="roster__companion">
        <strong><%= pc.name %></strong>
        <span class="roster__meta"><%= pc.class_name %> <%= pc.level %></span>
        <span class="roster__status"><%= declared_ids.include?(pc.id) ? "✓ declared" : "DM-run" %></span>
      </div>
    <% end %>
  </section>
</aside>
```

- [ ] **Step 5: Run all play component specs**

Run: `bundle exec rspec spec/components/play/`
Expected: green.

- [ ] **Step 6: Commit**

```bash
git add app/components/play/composer_component.{rb,html.erb} \
        app/components/play/state_indicator_component.{rb,html.erb} \
        app/components/play/roster/ \
        spec/components/play/composer_component_spec.rb \
        spec/components/play/state_indicator_component_spec.rb \
        spec/components/play/roster/sidebar_component_spec.rb
git commit -m "Add play surface chat-layout components (composer, state indicator, roster sidebar)"
```

---

### Task 27: Update Play::Scenes::PlayComponent — chat layout

**Files:**
- Modify: `app/components/play/scenes/play_component.{rb,html.erb}`
- Modify: `spec/components/play/scenes/play_component_spec.rb`

- [ ] **Step 1: Update the spec**

Update or extend the play component spec to expect: chat stream, composer, state indicator, roster sidebar, disabled scene picker.

```ruby
describe "Phase 9.1 layout" do
  it "renders the composer" do
    rendered = render_inline(described_class.new(scene: scene))
    expect(rendered.to_s).to include("composer")
  end

  it "renders the roster sidebar" do
    rendered = render_inline(described_class.new(scene: scene))
    expect(rendered.to_s).to include("roster")
  end

  it "disables the scene picker with tooltip" do
    rendered = render_inline(described_class.new(scene: scene))
    expect(rendered.to_s).to include("Scene transitions arrive in Phase 9.3")
  end
end
```

- [ ] **Step 2: Update the template**

Rewrite `app/components/play/scenes/play_component.html.erb`:

```erb
<%= helpers.turbo_stream_from [ scene, scene.campaign.user ] %>

<header class="play-header">
  <h1><%= scene.campaign.name %></h1>
  <h2><%= scene.title %></h2>
  <button disabled title="Scene transitions arrive in Phase 9.3">Scenes ▾</button>
</header>

<div class="play-grid">
  <main class="play-stream">
    <% scene.events.order(:occurred_at, :id).each do |event| %>
      <%= render Play::Events::Component.for(event) %>
    <% end %>
  </main>

  <%= render Play::Roster::SidebarComponent.new(scene: scene) %>
</div>

<%= render Play::StateIndicatorComponent.new(scene: scene) %>
<%= render Play::ComposerComponent.new(scene: scene) %>
```

(Remove any oracle form references; remove the bottom dice form — dice now flow through chips + the composer.)

- [ ] **Step 3: Run spec**

Run: `bundle exec rspec spec/components/play/scenes/play_component_spec.rb`
Expected: green.

- [ ] **Step 4: Commit**

```bash
git add app/components/play/scenes/play_component.{rb,html.erb} \
        spec/components/play/scenes/play_component_spec.rb
git commit -m "Play::Scenes::PlayComponent: chat layout (stream + composer + roster + state indicator); scene picker disabled"
```

---

## Phase 9 — Seed migration & asymmetry coverage

### Task 28: Update db/seeds.rb — extract PCs, scene secrets, drop chaos_factor

**Files:**
- Modify: `db/seeds.rb`
- Run: `bin/rails db:seed`

- [ ] **Step 1: Refactor seeds — split description**

Open `db/seeds.rb`. Replace the existing `campaign_description` heredoc with a short player-safe summary:

```ruby
campaign_description = <<~DESC.strip
  A 3-hour one-shot dungeon crawl for 1st-level characters set in Phandalin
  on the Sword Coast. The party is hired by the captain of the city guard
  to investigate undead attacks emanating from an old cemetery outside town.
  By Michael Klamerus (DMsGuild, 2016).
DESC
```

(All DM encounter content and party rosters are extracted below.)

- [ ] **Step 2: Add `scene_secrets` seeding**

Open the **current** (pre-modification) `db/seeds.rb` and extract the 11 paragraphs of DM encounter content that currently live inside the `campaign_description` heredoc under the `# DM Encounter Map` section — one paragraph per `## Scene N — <title>` heading (lines roughly 27–109 in the current file). The scene titles in the heredoc match the scene titles in the seeded `scenes` array verbatim.

Add (after scenes are created):

```ruby
SCENE_SECRETS = {
  "Cemetery & Tomb Approach"       => <<~TEXT,
    Captain Aldridge is here, waiting at the gate. Two unnamed city soldiers
    stand at the tomb door. No combat. The captain delivers his briefing
    (see his NPC entry) and unbars the tomb door at the party's request.
  TEXT
  "The Tomb — Entrance Hall"       => <<~TEXT,
    2 Skeletons (MM 272) are at the left door, trying to break through to
    the side chamber. They do not notice the party at first; will notice
    if anyone fails a Stealth check or stands too long in the open. CR 1/4
    each, 100 XP for the pair.
  TEXT
  "The Tomb — West Side Chamber"   => "<paste the 'Scene 3 — Tomb West Side Chamber' paragraph verbatim>",
  "The Tomb — North Chamber"       => "<paste the 'Scene 4 — Tomb North Chamber (Crematorium)' paragraph verbatim>",
  "The Tomb — East Hallway"        => "<paste the 'Scene 5 — Tomb East Hallway' paragraph verbatim>",
  "The Tomb — Far Chamber"         => "<paste the 'Scene 6 — Tomb Far Chamber' paragraph verbatim>",
  "The Caverns — Entrance"         => "<paste the 'Scene 7 — Caverns Entrance' paragraph verbatim>",
  "The Caverns — West Tunnel"      => "<paste the 'Scene 8 — Caverns West Tunnel' paragraph verbatim>",
  "The Caverns — East Tunnel"      => "<paste the 'Scene 9 — Caverns East Tunnel' paragraph verbatim>",
  "The Caverns — Deepest Chamber"  => "<paste the 'Scene 10 — Caverns Deepest Chamber' paragraph verbatim>",
  "Return to Phandalin"            => "<paste the 'Scene 11 — Return to Phandalin' paragraph verbatim>"
}.freeze

campaign.scenes.each do |scene|
  content = SCENE_SECRETS[scene.title]
  next unless content
  secret = scene.scene_secrets.find_or_initialize_by(label: "Encounter map")
  secret.content = content.strip
  secret.save!
end
```

Replace each `<paste…>` literal with the corresponding heredoc paragraph from the current file before saving.

- [ ] **Step 3: Add `player_character` seeding**

Open the **current** `db/seeds.rb`. The four PCs are documented in the `# Party Roster` section of the heredoc (lines roughly 111–191): one `##` heading per PC, then the full stat block as free-form prose. Each PC's `notes` value should be the entire body of their section (everything between their `##` heading and the next `##` heading), with leading indentation preserved.

Add (after the campaign is created, before scenes):

```ruby
PC_SEEDS = [
  {
    name: "Aragorn", role: "pc", class_name: "Ranger", level: 1, pronouns: "he/him",
    notes: <<~NOTES.strip
      Human Ranger 1 (Guide background, Chaotic Good, male, Medium)
      <PASTE the rest of Aragorn's stat block verbatim from the existing
      campaign.description, starting with "AC 15 (studded leather)..." and
      ending with the last spell line.>
    NOTES
  },
  {
    name: "Caine", role: "companion", class_name: "Monk", level: 1, pronouns: "he/him",
    notes: <<~NOTES.strip
      Goliath Monk 1 (Sage background, Medium)
      <PASTE the rest of Caine's stat block verbatim.>
    NOTES
  },
  {
    name: "Fred", role: "companion", class_name: "Cleric", level: 1, pronouns: "he/him",
    notes: <<~NOTES.strip
      Dwarf Cleric 1 (Acolyte background, Medium)
      <PASTE the rest of Fred's stat block verbatim.>
    NOTES
  },
  {
    name: "Patric", role: "companion", class_name: "Wizard", level: 1, pronouns: "he/him",
    notes: <<~NOTES.strip
      Human Wizard 1 (Charlatan background, Chaotic Good, male, Medium)
      <PASTE the rest of Patric's stat block verbatim.>
    NOTES
  }
].freeze

PC_SEEDS.each do |attrs|
  pc = campaign.player_characters.find_or_initialize_by(name: attrs[:name])
  pc.assign_attributes(attrs)
  pc.save!
end

aragorn = campaign.player_characters.find_by!(name: "Aragorn")
campaign.update!(main_character: aragorn)
```

- [ ] **Step 4: Remove `chaos_factor` seeding**

Delete the line `campaign.chaos_factor = 5 if campaign.new_record?`.

- [ ] **Step 5: Run seed**

Run:
```bash
bin/rails db:reset
bin/rails db:seed
```
Expected: completes; output shows `4 player characters`, `11 scene secrets`.

- [ ] **Step 6: Commit**

```bash
git add db/seeds.rb
git commit -m "Seeds: extract Phandalin PCs and per-scene encounter maps; drop chaos_factor"
```

---

### Task 29: Update asymmetry coverage meta-spec

**Files:**
- Modify: `spec/asymmetry/coverage_spec.rb`
- Verify: all new VMs and components have `leak_secrets_of` references in their specs

- [ ] **Step 1: Run the meta-spec to see current failures**

Run: `bundle exec rspec spec/asymmetry/coverage_spec.rb`
Expected: failures listing any new `Player::*ViewModel` or `Play::*Component` without coverage.

- [ ] **Step 2: For each failure, ensure the corresponding spec contains `leak_secrets_of`**

The component specs in Tasks 23 and 26 already include asymmetry blocks. Verify the meta-spec's EXEMPT_COMPONENTS list is appropriate; if any new component is genuinely contentless (e.g., utility-only), add it with a stated reason. New entries:
- `Play::ComposerComponent` — has the asymmetry block (Task 26)
- `Play::StateIndicatorComponent` — has the asymmetry block
- `Play::Roster::SidebarComponent` — has the asymmetry block
- `Play::Events::PcDeclarationComponent` — has the asymmetry block
- `Play::Events::GmCollectionPromptComponent` — has the asymmetry block

The new `Player::PlayerCharacterViewModel` and `Player::SceneStateViewModel` both already have specs with `leak_secrets_of` (Task 6 and 8). `SceneStateViewModel` is metadata-only — add a `describe "asymmetry"` block to its spec asserting it doesn't leak.

- [ ] **Step 3: Remove oracle references from coverage**

Remove any `Play::Events::OracleQueryComponent` (or similar) from EXEMPT_COMPONENTS or any explicit registration — Task 21 deleted those classes.

- [ ] **Step 4: Run the meta-spec**

Run: `bundle exec rspec spec/asymmetry/coverage_spec.rb`
Expected: green.

- [ ] **Step 5: Commit**

```bash
git add spec/asymmetry/coverage_spec.rb spec/view_models/ spec/components/
git commit -m "Asymmetry coverage: register new VMs/components; drop oracle entries"
```

---

## Phase 10 — Integration + playtest gate

### Task 30: End-to-end feature spec (mocked LLM)

**Files:**
- Create: `spec/system/phase_9_1_turn_discipline_spec.rb`

- [ ] **Step 1: Write a system spec covering scene-start → declare → resolve → mid-roll → continue**

```ruby
require "rails_helper"

RSpec.describe "Phase 9.1 turn discipline", type: :system, js: true do
  include ActiveJob::TestHelper

  let(:user)     { create(:user, password: "password123") }
  let(:campaign) { create(:campaign, user:, name: "Test") }
  let!(:aragorn) { create(:player_character, campaign:, name: "Aragorn", role: "pc").tap { campaign.update!(main_character: _1) } }
  let!(:caine)   { create(:player_character, campaign:, name: "Caine",   role: "companion") }
  let(:scene)    { create(:scene, campaign:, title: "Test Scene") }

  before do
    ActionCable.server.config.cable = { "adapter" => "async" }
    ActionCable.server.restart
    Llm::Providers::Anthropic.reset_client!
    stub_anthropic_streaming(deltas: [ "You see a door. ", "What does Aragorn do?" ])
    sign_in user
  end

  it "frames on load, collects declarations, resolves, and continues after roll" do
    visit play_scene_path(scene)

    expect(page).to have_text("You see a door.", wait: 5)
    expect(page).to have_text("What does Aragorn do?")

    stub_anthropic_streaming(deltas: [ "The door creaks. ", "Anything else?" ])
    fill_in :text, with: "I push the door open."
    click_button "Send"

    expect(page).to have_text("Anything for Caine") # companion check appears
    fill_in :text, with: "go"
    click_button "Send"

    # Resolution narration appears
    expect(page).to have_text("The door creaks.", wait: 5)
  end
end
```

- [ ] **Step 2: Run the system spec**

Run: `bundle exec rspec spec/system/phase_9_1_turn_discipline_spec.rb`
Expected: green.

- [ ] **Step 3: Commit**

```bash
git add spec/system/phase_9_1_turn_discipline_spec.rb
git commit -m "Add Phase 9.1 turn-discipline system spec (framing → collect → resolve)"
```

---

### Task 31: Manual playtest + log

**Files:**
- Create: `docs/superpowers/playtests/<YYYY-MM-DD>-phase-9-1.md`

- [ ] **Step 1: Run the full spec suite**

Run: `bundle exec rspec`
Expected: green. If anything fails, address in the relevant earlier task, do NOT skip.

- [ ] **Step 2: Run linter**

Run: `bin/rubocop`
Fix any new violations introduced by this plan.

- [ ] **Step 3: Deploy to staging or run locally**

```bash
bin/dev # or your deploy command
```

Open the play surface for the Phandalin scene 1.

- [ ] **Step 4: Manual playtest gate (per spec acceptance criteria)**

Execute the playtest gate from the spec:
- Captain delivers his briefing
- Multi-turn declare→resolve cycles (≥ 3)
- At least one mid-turn dice request
- At least one companion DM-voiced beat

Capture observations as you go.

- [ ] **Step 5: Write the playtest log**

Create `docs/superpowers/playtests/<today>-phase-9-1.md` documenting:
- Date / environment / scene
- Verdict (pass / fail / partial)
- Specifically: any narration where the agent generated PC actions/dialogue (must be zero — that's the blocker test)
- Any literal `[Turn N]`, `[player_action @`, `**`, `#` showing as text (must be zero)
- Specific dice chips that worked / didn't work
- Companion voicings that landed / felt wrong

- [ ] **Step 6: Commit**

```bash
git add docs/superpowers/playtests/<today>-phase-9-1.md
git commit -m "Add Phase 9.1 playtest log — turn discipline verified end-to-end"
```

---

## Done

Phase 9.1 ships when:

- [ ] All tasks above checked off
- [ ] `bundle exec rspec` green
- [ ] `bin/rubocop` green
- [ ] Playtest log committed with passing verdict
- [ ] Issues #12, #13, #14, #15, #19, #25 closed with reference to the playtest log

Successor phases: **9.2 (combat)**, **9.3 (scene transitions, closes #16)**, then issues **#17** (faction/NPC admin CRUD) and **#18** (Solid Queue in Puma) — collectively close Phase 9 (#10).
