# v2 Phase 5 — Asymmetry schema + ViewModels: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the six asymmetry tables (`factions`/`faction_secrets`, `npcs`/`npc_secrets`, `scenes`, `events`), the `ApplicationViewModel` base with an `expose` DSL, four asymmetric ViewModels (Player + Narrator for Faction and Npc), the `not_to_leak` matcher infrastructure, and the supporting factory + model + ViewModel specs. End-state: `bundle exec rspec` green, no UI, no controllers, no service objects.

**Architecture:** Six new Rails 8 ActiveRecord models rooted at `Campaign` (cascade FK). Many-row `*_secrets` tables (open list of named hidden facts), `acts_as_list`-ordered `Scene`, and a single-table `Event` with a `kind` enum + `payload` jsonb. ViewModels are POROs under `app/view_models/`; the `ApplicationViewModel` base provides a class-level `expose` DSL (attr-list or block form) that records the exposed attribute set and powers a recursive `to_h`. Two custom RSpec matchers (`leak_secrets_of`, `expose_attrs_via`) live in `spec/support/matchers/not_to_leak.rb` and form the structural + dynamic asymmetry test surface.

**Tech Stack:** Rails 8.1 · PostgreSQL · `acts_as_list` gem · RSpec · factory_bot · shoulda-matchers · annotaterb.

**Spec:** [`docs/superpowers/specs/2026-05-14-v2-phase-5-asymmetry-schema-and-viewmodels-design.md`](../specs/2026-05-14-v2-phase-5-asymmetry-schema-and-viewmodels-design.md).

**Issue:** [#6](https://github.com/barriault/gygaxagain/issues/6).

---

## File structure

**Gem (Task 1):**
- `Gemfile`, `Gemfile.lock` — modified

**Migrations + models (Tasks 2–7):**
- `db/migrate/<ts>_create_factions.rb` — new
- `db/migrate/<ts>_create_faction_secrets.rb` — new
- `db/migrate/<ts>_create_npcs.rb` — new
- `db/migrate/<ts>_create_npc_secrets.rb` — new
- `db/migrate/<ts>_create_scenes.rb` — new
- `db/migrate/<ts>_create_events.rb` — new
- `app/models/faction.rb`, `faction_secret.rb`, `npc.rb`, `npc_secret.rb`, `scene.rb`, `event.rb` — new
- `app/models/campaign.rb` — modified (`has_many :factions`, `has_many :npcs`, `has_many :scenes`)
- `spec/factories/factions.rb`, `faction_secrets.rb`, `npcs.rb`, `npc_secrets.rb`, `scenes.rb`, `events.rb` — new
- `spec/models/faction_spec.rb`, `faction_secret_spec.rb`, `npc_spec.rb`, `npc_secret_spec.rb`, `scene_spec.rb`, `event_spec.rb` — new

**LlmCall ↔ Scene wire-up (Task 8):**
- `db/migrate/<ts>_add_scene_foreign_key_to_llm_calls.rb` — new
- `app/models/llm_call.rb` — modified (uncomment `belongs_to :scene`)
- `app/models/scene.rb` — modified (`has_many :llm_calls`)
- `spec/models/llm_call_spec.rb` — modified
- `spec/models/scene_spec.rb` — modified

**ViewModel base + matchers (Tasks 9–11):**
- `app/view_models/application_view_model.rb` — new
- `spec/view_models/application_view_model_spec.rb` — new
- `spec/support/matchers/not_to_leak.rb` — new
- `spec/support/matchers/not_to_leak_spec.rb` — new

**ViewModels (Tasks 12–14):**
- `app/view_models/player/faction_view_model.rb` — new
- `app/view_models/player/npc_view_model.rb` — new
- `app/view_models/narrator/faction_view_model.rb` — new
- `app/view_models/narrator/faction_secret_view_model.rb` — new
- `app/view_models/narrator/npc_view_model.rb` — new
- `app/view_models/narrator/npc_secret_view_model.rb` — new
- `spec/view_models/player/faction_view_model_spec.rb` — new
- `spec/view_models/player/npc_view_model_spec.rb` — new
- `spec/view_models/narrator/faction_view_model_spec.rb` — new
- `spec/view_models/narrator/faction_secret_view_model_spec.rb` — new
- `spec/view_models/narrator/npc_view_model_spec.rb` — new
- `spec/view_models/narrator/npc_secret_view_model_spec.rb` — new

**Final pass (Task 15):**
- `app/models/*.rb`, `spec/factories/*.rb` — annotation refresh
- README touched only if a Phase 5 line needs to land (not anticipated)

---

## Task 1: Add `acts_as_list` gem

**Files:**
- Modify: `Gemfile`
- Modify: `Gemfile.lock`

- [ ] **Step 1: Add the gem to the default group**

Edit `Gemfile`. Locate the `gem "anthropic"` line near the top (currently the first alphabetical entry below the `rails` and ruby-version directives). Insert immediately above it:

```ruby
gem "acts_as_list"
```

The default-group section should now begin:

```ruby
gem "rails", "~> 8.1.3"

gem "acts_as_list"
gem "anthropic"
gem "bootsnap", require: false
```

- [ ] **Step 2: Install the gem**

Run: `bundle install`
Expected: `Bundle complete!` with `acts_as_list` appearing in installation output. `Gemfile.lock` should be modified.

- [ ] **Step 3: Verify existing test suite still passes**

Run: `bundle exec rspec`
Expected: all existing Phase 1–4 specs pass. No new specs yet.

- [ ] **Step 4: Commit**

```bash
git add Gemfile Gemfile.lock
git commit -m "Add acts_as_list gem (Phase 5.1)"
```

---

## Task 2: Faction model

**Files:**
- Create: `db/migrate/<ts>_create_factions.rb`
- Create: `app/models/faction.rb`
- Create: `spec/factories/factions.rb`
- Create: `spec/models/faction_spec.rb`
- Modify: `app/models/campaign.rb`

- [ ] **Step 1: Generate the migration scaffold**

Run: `bin/rails generate migration CreateFactions`
Expected: a file `db/migrate/<timestamp>_create_factions.rb` is created.

- [ ] **Step 2: Fill in the migration**

Open the new migration file. Replace its body with:

```ruby
class CreateFactions < ActiveRecord::Migration[8.1]
  def change
    create_table :factions do |t|
      t.references :campaign, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.text :public_description
      t.timestamps
    end

    add_index :factions, "campaign_id, lower(name)",
              unique: true,
              name: "index_factions_on_campaign_id_and_lower_name"
  end
end
```

- [ ] **Step 3: Run the migration**

Run: `bin/rails db:migrate`
Expected: migration runs cleanly; `db/schema.rb` updates with the `factions` table and both indexes (`index_factions_on_campaign_id` plus the functional unique index).

- [ ] **Step 4: Write the factory**

Create `spec/factories/factions.rb`:

```ruby
FactoryBot.define do
  factory :faction do
    campaign
    sequence(:name) { |n| "Faction #{n}" }
    public_description { "A public-facing description." }

    trait :with_secrets do
      after(:create) do |faction|
        create_list(:faction_secret, 2, faction: faction)
      end
    end
  end
end
```

(Annotation header gets added by `annotaterb` in Task 15. The `:with_secrets` trait creates two `FactionSecret` children. It's not exercised by Phase 5's own specs — they create secrets explicitly to control labels/contents per test — but it's listed in the spec and useful for future phases.)

- [ ] **Step 5: Write the failing model spec**

Create `spec/models/faction_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Faction, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:campaign) }
  end

  describe "validations" do
    subject { build(:faction) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:campaign_id).case_insensitive }
  end

  describe "cascade on campaign delete" do
    it "removes factions when their campaign is deleted at the DB level" do
      campaign = create(:campaign)
      faction = create(:faction, campaign: campaign)
      ActiveRecord::Base.connection.execute("DELETE FROM campaigns WHERE id = #{campaign.id}")
      expect(Faction.where(id: faction.id)).to be_empty
    end
  end
end
```

- [ ] **Step 6: Run the spec to verify it fails**

Run: `bundle exec rspec spec/models/faction_spec.rb`
Expected: failure with `NameError: uninitialized constant Faction` (or similar — the model file doesn't exist yet).

- [ ] **Step 7: Write the Faction model**

Create `app/models/faction.rb`:

```ruby
class Faction < ApplicationRecord
  belongs_to :campaign

  validates :name, presence: true,
                   length: { maximum: 100 },
                   uniqueness: { scope: :campaign_id, case_sensitive: false }
end
```

(Annotation header gets added by `annotaterb` in Task 15. `has_many :secrets` lands with the FactionSecret model in Task 3.)

- [ ] **Step 8: Wire `has_many :factions` on Campaign**

Edit `app/models/campaign.rb`. Locate the existing `has_many :llm_calls, dependent: :destroy` line. Add immediately below it:

```ruby
  has_many :factions, dependent: :destroy
```

The block of associations should now read (DB FK cascade handles the data side; the `dependent: :destroy` keeps Rails callbacks in sync for objects loaded into memory):

```ruby
class Campaign < ApplicationRecord
  belongs_to :user
  has_many :llm_calls, dependent: :destroy
  has_many :factions, dependent: :destroy

  validates :name, presence: true,
                   length: { maximum: 100 },
                   uniqueness: { scope: :user_id, case_sensitive: false }
end
```

- [ ] **Step 9: Run the spec to verify it passes**

Run: `bundle exec rspec spec/models/faction_spec.rb`
Expected: all examples pass (associations, validations, cascade).

- [ ] **Step 10: Run the full suite to verify no regression**

Run: `bundle exec rspec`
Expected: green overall.

- [ ] **Step 11: Commit**

```bash
git add db/migrate db/schema.rb app/models/faction.rb app/models/campaign.rb spec/factories/factions.rb spec/models/faction_spec.rb
git commit -m "Add Faction model (Phase 5.2)"
```

---

## Task 3: FactionSecret model

**Files:**
- Create: `db/migrate/<ts>_create_faction_secrets.rb`
- Create: `app/models/faction_secret.rb`
- Create: `spec/factories/faction_secrets.rb`
- Create: `spec/models/faction_secret_spec.rb`
- Modify: `app/models/faction.rb`

- [ ] **Step 1: Generate and fill the migration**

Run: `bin/rails generate migration CreateFactionSecrets`. Replace the generated file body with:

```ruby
class CreateFactionSecrets < ActiveRecord::Migration[8.1]
  def change
    create_table :faction_secrets do |t|
      t.references :faction, null: false, foreign_key: { on_delete: :cascade }
      t.string :label, null: false
      t.text :content, null: false
      t.timestamps
    end
  end
end
```

- [ ] **Step 2: Run the migration**

Run: `bin/rails db:migrate`
Expected: `faction_secrets` table created; schema updated.

- [ ] **Step 3: Write the factory**

Create `spec/factories/faction_secrets.rb`:

```ruby
FactoryBot.define do
  factory :faction_secret do
    faction
    sequence(:label) { |n| "Hidden fact #{n}" }
    content { "This is hidden content the player must not see." }
  end
end
```

- [ ] **Step 4: Write the failing spec**

Create `spec/models/faction_secret_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe FactionSecret, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:faction) }
  end

  describe "validations" do
    subject { build(:faction_secret) }

    it { is_expected.to validate_presence_of(:label) }
    it { is_expected.to validate_length_of(:label).is_at_most(100) }
    it { is_expected.to validate_presence_of(:content) }
  end

  describe "cascade on faction delete" do
    it "removes faction_secrets when their faction is deleted at the DB level" do
      faction = create(:faction)
      secret = create(:faction_secret, faction: faction)
      ActiveRecord::Base.connection.execute("DELETE FROM factions WHERE id = #{faction.id}")
      expect(FactionSecret.where(id: secret.id)).to be_empty
    end
  end
end
```

- [ ] **Step 5: Run the spec to verify it fails**

Run: `bundle exec rspec spec/models/faction_secret_spec.rb`
Expected: failure with `NameError: uninitialized constant FactionSecret`.

- [ ] **Step 6: Write the FactionSecret model**

Create `app/models/faction_secret.rb`:

```ruby
class FactionSecret < ApplicationRecord
  belongs_to :faction

  validates :label,   presence: true, length: { maximum: 100 }
  validates :content, presence: true
end
```

- [ ] **Step 7: Wire `has_many :secrets` on Faction**

Edit `app/models/faction.rb`. Add the association so the class becomes:

```ruby
class Faction < ApplicationRecord
  belongs_to :campaign
  has_many :secrets, class_name: "FactionSecret", dependent: :destroy

  validates :name, presence: true,
                   length: { maximum: 100 },
                   uniqueness: { scope: :campaign_id, case_sensitive: false }
end
```

- [ ] **Step 8: Run the spec to verify it passes**

Run: `bundle exec rspec spec/models/faction_secret_spec.rb spec/models/faction_spec.rb`
Expected: green on both.

- [ ] **Step 9: Run the full suite**

Run: `bundle exec rspec`
Expected: green overall.

- [ ] **Step 10: Commit**

```bash
git add db/migrate db/schema.rb app/models/faction_secret.rb app/models/faction.rb spec/factories/faction_secrets.rb spec/models/faction_secret_spec.rb
git commit -m "Add FactionSecret model (Phase 5.3)"
```

---

## Task 4: Npc model

**Files:**
- Create: `db/migrate/<ts>_create_npcs.rb`
- Create: `app/models/npc.rb`
- Create: `spec/factories/npcs.rb`
- Create: `spec/models/npc_spec.rb`
- Modify: `app/models/campaign.rb`

- [ ] **Step 1: Generate and fill the migration**

Run: `bin/rails generate migration CreateNpcs`. Replace the file body with:

```ruby
class CreateNpcs < ActiveRecord::Migration[8.1]
  def change
    create_table :npcs do |t|
      t.references :campaign, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.text :public_description
      t.string :location
      t.timestamps
    end
  end
end
```

- [ ] **Step 2: Run the migration**

Run: `bin/rails db:migrate`
Expected: `npcs` table created.

- [ ] **Step 3: Write the factory**

Create `spec/factories/npcs.rb`:

```ruby
FactoryBot.define do
  factory :npc do
    campaign
    sequence(:name) { |n| "NPC #{n}" }
    public_description { "A public-facing description." }
    location { "Somewhere visible" }

    trait :with_secrets do
      after(:create) do |npc|
        create_list(:npc_secret, 2, npc: npc)
      end
    end
  end
end
```

- [ ] **Step 4: Write the failing spec**

Create `spec/models/npc_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Npc, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:campaign) }
  end

  describe "validations" do
    subject { build(:npc) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }
  end

  describe "name uniqueness" do
    it "does NOT enforce per-campaign uniqueness on name" do
      campaign = create(:campaign)
      create(:npc, campaign: campaign, name: "John")
      duplicate = build(:npc, campaign: campaign, name: "John")
      expect(duplicate).to be_valid
    end
  end

  describe "cascade on campaign delete" do
    it "removes npcs when their campaign is deleted at the DB level" do
      campaign = create(:campaign)
      npc = create(:npc, campaign: campaign)
      ActiveRecord::Base.connection.execute("DELETE FROM campaigns WHERE id = #{campaign.id}")
      expect(Npc.where(id: npc.id)).to be_empty
    end
  end
end
```

- [ ] **Step 5: Run the spec to verify it fails**

Run: `bundle exec rspec spec/models/npc_spec.rb`
Expected: failure with `NameError: uninitialized constant Npc`.

- [ ] **Step 6: Write the Npc model**

Create `app/models/npc.rb`:

```ruby
class Npc < ApplicationRecord
  belongs_to :campaign

  validates :name, presence: true, length: { maximum: 100 }
end
```

(`has_many :secrets` lands with the NpcSecret model in Task 5.)

- [ ] **Step 7: Wire `has_many :npcs` on Campaign**

Edit `app/models/campaign.rb` to add the association directly under `has_many :factions`:

```ruby
  has_many :npcs, dependent: :destroy
```

- [ ] **Step 8: Run the spec to verify it passes**

Run: `bundle exec rspec spec/models/npc_spec.rb`
Expected: green.

- [ ] **Step 9: Run the full suite**

Run: `bundle exec rspec`
Expected: green overall.

- [ ] **Step 10: Commit**

```bash
git add db/migrate db/schema.rb app/models/npc.rb app/models/campaign.rb spec/factories/npcs.rb spec/models/npc_spec.rb
git commit -m "Add Npc model (Phase 5.4)"
```

---

## Task 5: NpcSecret model

**Files:**
- Create: `db/migrate/<ts>_create_npc_secrets.rb`
- Create: `app/models/npc_secret.rb`
- Create: `spec/factories/npc_secrets.rb`
- Create: `spec/models/npc_secret_spec.rb`
- Modify: `app/models/npc.rb`

- [ ] **Step 1: Generate and fill the migration**

Run: `bin/rails generate migration CreateNpcSecrets`. Replace the file body with:

```ruby
class CreateNpcSecrets < ActiveRecord::Migration[8.1]
  def change
    create_table :npc_secrets do |t|
      t.references :npc, null: false, foreign_key: { on_delete: :cascade }
      t.string :label, null: false
      t.text :content, null: false
      t.timestamps
    end
  end
end
```

- [ ] **Step 2: Run the migration**

Run: `bin/rails db:migrate`
Expected: `npc_secrets` table created.

- [ ] **Step 3: Write the factory**

Create `spec/factories/npc_secrets.rb`:

```ruby
FactoryBot.define do
  factory :npc_secret do
    npc
    sequence(:label) { |n| "Hidden NPC fact #{n}" }
    content { "This is hidden content the player must not see." }
  end
end
```

- [ ] **Step 4: Write the failing spec**

Create `spec/models/npc_secret_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe NpcSecret, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:npc) }
  end

  describe "validations" do
    subject { build(:npc_secret) }

    it { is_expected.to validate_presence_of(:label) }
    it { is_expected.to validate_length_of(:label).is_at_most(100) }
    it { is_expected.to validate_presence_of(:content) }
  end

  describe "cascade on npc delete" do
    it "removes npc_secrets when their npc is deleted at the DB level" do
      npc = create(:npc)
      secret = create(:npc_secret, npc: npc)
      ActiveRecord::Base.connection.execute("DELETE FROM npcs WHERE id = #{npc.id}")
      expect(NpcSecret.where(id: secret.id)).to be_empty
    end
  end
end
```

- [ ] **Step 5: Run the spec to verify it fails**

Run: `bundle exec rspec spec/models/npc_secret_spec.rb`
Expected: failure with `NameError: uninitialized constant NpcSecret`.

- [ ] **Step 6: Write the NpcSecret model**

Create `app/models/npc_secret.rb`:

```ruby
class NpcSecret < ApplicationRecord
  belongs_to :npc

  validates :label,   presence: true, length: { maximum: 100 }
  validates :content, presence: true
end
```

- [ ] **Step 7: Wire `has_many :secrets` on Npc**

Edit `app/models/npc.rb` so it reads:

```ruby
class Npc < ApplicationRecord
  belongs_to :campaign
  has_many :secrets, class_name: "NpcSecret", dependent: :destroy

  validates :name, presence: true, length: { maximum: 100 }
end
```

- [ ] **Step 8: Run the spec to verify it passes**

Run: `bundle exec rspec spec/models/npc_secret_spec.rb spec/models/npc_spec.rb`
Expected: green on both.

- [ ] **Step 9: Run the full suite**

Run: `bundle exec rspec`
Expected: green overall.

- [ ] **Step 10: Commit**

```bash
git add db/migrate db/schema.rb app/models/npc_secret.rb app/models/npc.rb spec/factories/npc_secrets.rb spec/models/npc_secret_spec.rb
git commit -m "Add NpcSecret model (Phase 5.5)"
```

---

## Task 6: Scene model with `acts_as_list`

**Files:**
- Create: `db/migrate/<ts>_create_scenes.rb`
- Create: `app/models/scene.rb`
- Create: `spec/factories/scenes.rb`
- Create: `spec/models/scene_spec.rb`
- Modify: `app/models/campaign.rb`

- [ ] **Step 1: Generate and fill the migration**

Run: `bin/rails generate migration CreateScenes`. Replace the file body with:

```ruby
class CreateScenes < ActiveRecord::Migration[8.1]
  def change
    create_table :scenes do |t|
      t.references :campaign, null: false, foreign_key: { on_delete: :cascade }
      t.string :title, null: false
      t.text :summary
      t.integer :position, null: false
      t.timestamps
    end

    add_index :scenes, [:campaign_id, :position]
  end
end
```

- [ ] **Step 2: Run the migration**

Run: `bin/rails db:migrate`
Expected: `scenes` table created with the composite index.

- [ ] **Step 3: Write the factory**

Create `spec/factories/scenes.rb`:

```ruby
FactoryBot.define do
  factory :scene do
    campaign
    sequence(:title) { |n| "Scene #{n}" }
    summary { "A short scene summary." }
    # position auto-assigned by acts_as_list
  end
end
```

- [ ] **Step 4: Write the failing spec**

Create `spec/models/scene_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Scene, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:campaign) }
  end

  describe "validations" do
    subject { build(:scene) }

    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_length_of(:title).is_at_most(100) }
  end

  describe "acts_as_list ordering" do
    let(:campaign) { create(:campaign) }
    let!(:first)   { create(:scene, campaign: campaign, title: "First") }
    let!(:second)  { create(:scene, campaign: campaign, title: "Second") }
    let!(:third)   { create(:scene, campaign: campaign, title: "Third") }

    it "auto-assigns sequential positions within a campaign" do
      expect([first.reload.position, second.reload.position, third.reload.position]).to eq([1, 2, 3])
    end

    it "scopes positions to the campaign (a second campaign's scenes restart at 1)" do
      other_campaign = create(:campaign)
      other_scene = create(:scene, campaign: other_campaign)
      expect(other_scene.reload.position).to eq(1)
    end

    it "reorders via move_higher!" do
      third.move_higher
      expect([first.reload.position, second.reload.position, third.reload.position]).to eq([1, 3, 2])
    end

    it "first? and last? report position correctly" do
      expect(first.reload).to be_first
      expect(third.reload).to be_last
    end
  end

  describe "cascade on campaign delete" do
    it "removes scenes when their campaign is deleted at the DB level" do
      campaign = create(:campaign)
      scene = create(:scene, campaign: campaign)
      ActiveRecord::Base.connection.execute("DELETE FROM campaigns WHERE id = #{campaign.id}")
      expect(Scene.where(id: scene.id)).to be_empty
    end
  end
end
```

- [ ] **Step 5: Run the spec to verify it fails**

Run: `bundle exec rspec spec/models/scene_spec.rb`
Expected: failure with `NameError: uninitialized constant Scene`.

- [ ] **Step 6: Write the Scene model**

Create `app/models/scene.rb`:

```ruby
class Scene < ApplicationRecord
  belongs_to :campaign

  acts_as_list scope: :campaign

  validates :title, presence: true, length: { maximum: 100 }
end
```

(`has_many :events` and `has_many :llm_calls` land in Tasks 7 and 8 respectively.)

- [ ] **Step 7: Wire `has_many :scenes` on Campaign**

Edit `app/models/campaign.rb` to add the association after `has_many :npcs`:

```ruby
  has_many :scenes, dependent: :destroy
```

- [ ] **Step 8: Run the spec to verify it passes**

Run: `bundle exec rspec spec/models/scene_spec.rb`
Expected: green.

- [ ] **Step 9: Run the full suite**

Run: `bundle exec rspec`
Expected: green overall.

- [ ] **Step 10: Commit**

```bash
git add db/migrate db/schema.rb app/models/scene.rb app/models/campaign.rb spec/factories/scenes.rb spec/models/scene_spec.rb
git commit -m "Add Scene model with acts_as_list (Phase 5.6)"
```

---

## Task 7: Event model with `kind` enum + jsonb payload

**Files:**
- Create: `db/migrate/<ts>_create_events.rb`
- Create: `app/models/event.rb`
- Create: `spec/factories/events.rb`
- Create: `spec/models/event_spec.rb`
- Modify: `app/models/scene.rb`

- [ ] **Step 1: Generate and fill the migration**

Run: `bin/rails generate migration CreateEvents`. Replace the file body with:

```ruby
class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.references :scene, null: false, foreign_key: { on_delete: :cascade }
      t.string :kind, null: false
      t.jsonb :payload, null: false, default: {}
      t.datetime :occurred_at, null: false
      t.timestamps
    end

    add_index :events, [:scene_id, :occurred_at]
    add_index :events, :kind
  end
end
```

- [ ] **Step 2: Run the migration**

Run: `bin/rails db:migrate`
Expected: `events` table created with both indexes.

- [ ] **Step 3: Write the factory**

Create `spec/factories/events.rb`:

```ruby
FactoryBot.define do
  factory :event do
    scene
    kind { "narration" }
    payload { { text: "Some narration." } }

    trait :dice_roll do
      kind { "dice_roll" }
      payload { { expression: "2d6+3", result: 10, breakdown: [4, 3, "+3"] } }
    end

    trait :oracle_query do
      kind { "oracle_query" }
      payload { { question: "Is it raining?", likelihood: "even_odds", chaos: 5, answer: "yes" } }
    end

    trait :scene_transition do
      kind { "scene_transition" }
      payload { { from_scene_id: nil, to_scene_id: nil, reason: "Player chose to leave." } }
    end
  end
end
```

- [ ] **Step 4: Write the failing spec**

Create `spec/models/event_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Event, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:scene) }
  end

  describe "kind enum" do
    %w[narration dice_roll oracle_query scene_transition].each do |kind|
      it "round-trips kind=#{kind}" do
        event = create(:event, kind: kind)
        expect(event.reload.kind).to eq(kind)
      end
    end

    it "raises ArgumentError on an unknown kind" do
      expect { build(:event, kind: "unknown_kind") }.to raise_error(ArgumentError)
    end
  end

  describe "occurred_at default" do
    it "defaults to Time.current on create when not provided" do
      freeze_time = Time.parse("2026-05-14 12:00:00 UTC")
      event = travel_to(freeze_time) { create(:event, occurred_at: nil) }
      expect(event.occurred_at).to be_within(1.second).of(freeze_time)
    end

    it "honors an explicit occurred_at" do
      t = 1.day.ago
      event = create(:event, occurred_at: t)
      expect(event.occurred_at).to be_within(1.second).of(t)
    end
  end

  describe "payload" do
    it "stores arbitrary jsonb" do
      event = create(:event, kind: "dice_roll", payload: { expression: "1d20" })
      expect(event.reload.payload).to eq("expression" => "1d20")
    end

    it "defaults to empty hash if not provided" do
      event = create(:event, payload: {})
      expect(event.reload.payload).to eq({})
    end
  end

  describe "cascade on scene delete" do
    it "removes events when their scene is deleted at the DB level" do
      scene = create(:scene)
      event = create(:event, scene: scene)
      ActiveRecord::Base.connection.execute("DELETE FROM scenes WHERE id = #{scene.id}")
      expect(Event.where(id: event.id)).to be_empty
    end
  end

  describe "trait factories" do
    it "creates a dice_roll event via trait" do
      event = create(:event, :dice_roll)
      expect(event.kind).to eq("dice_roll")
      expect(event.payload).to include("expression")
    end
  end
end
```

The `travel_to` helper requires `include ActiveSupport::Testing::TimeHelpers`. Add this to `spec/rails_helper.rb` inside the existing `RSpec.configure` block (locate the `config.fixture_paths = [...]` block and insert below the `config.filter_rails_from_backtrace!` line):

```ruby
  config.include ActiveSupport::Testing::TimeHelpers
```

- [ ] **Step 5: Run the spec to verify it fails**

Run: `bundle exec rspec spec/models/event_spec.rb`
Expected: failure with `NameError: uninitialized constant Event`.

- [ ] **Step 6: Write the Event model**

Create `app/models/event.rb`:

```ruby
class Event < ApplicationRecord
  KINDS = %w[narration dice_roll oracle_query scene_transition].freeze

  belongs_to :scene

  enum :kind, KINDS.index_with(&:itself)

  before_validation :default_occurred_at, on: :create
  validates :occurred_at, presence: true

  private

  def default_occurred_at
    self.occurred_at ||= Time.current
  end
end
```

- [ ] **Step 7: Wire `has_many :events` on Scene**

Edit `app/models/scene.rb` so it reads:

```ruby
class Scene < ApplicationRecord
  belongs_to :campaign
  has_many :events, dependent: :destroy

  acts_as_list scope: :campaign

  validates :title, presence: true, length: { maximum: 100 }
end
```

- [ ] **Step 8: Run the spec to verify it passes**

Run: `bundle exec rspec spec/models/event_spec.rb`
Expected: green on all examples.

- [ ] **Step 9: Run the full suite**

Run: `bundle exec rspec`
Expected: green overall.

- [ ] **Step 10: Commit**

```bash
git add db/migrate db/schema.rb app/models/event.rb app/models/scene.rb spec/factories/events.rb spec/models/event_spec.rb spec/rails_helper.rb
git commit -m "Add Event model with kind enum and jsonb payload (Phase 5.7)"
```

---

## Task 8: Wire `LlmCall ↔ Scene`

**Context.** `llm_calls.scene_id` was added in Phase 4 as a nullable column without a foreign key. The `LlmCall` model carries a commented-out `belongs_to :scene` with a note pointing here. Now that `scenes` exists, we add the FK with `on_delete: :nullify` (LlmCalls are audit records and should survive scene deletion with their scene reference cleared), enable the association, and add a reverse `has_many` on Scene.

**Files:**
- Create: `db/migrate/<ts>_add_scene_foreign_key_to_llm_calls.rb`
- Modify: `app/models/llm_call.rb`
- Modify: `app/models/scene.rb`
- Modify: `spec/models/llm_call_spec.rb`
- Modify: `spec/models/scene_spec.rb`

- [ ] **Step 1: Generate the migration**

Run: `bin/rails generate migration AddSceneForeignKeyToLlmCalls`. Replace the file body with:

```ruby
class AddSceneForeignKeyToLlmCalls < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :llm_calls, :scenes, on_delete: :nullify
  end
end
```

- [ ] **Step 2: Run the migration**

Run: `bin/rails db:migrate`
Expected: `db/schema.rb` adds `add_foreign_key "llm_calls", "scenes", on_delete: :nullify`.

- [ ] **Step 3: Add a failing spec for the new association on LlmCall**

Edit `spec/models/llm_call_spec.rb`. Add the following `describe` block inside the existing top-level `RSpec.describe LlmCall do ... end` (alongside any existing association blocks):

```ruby
  describe "scene association" do
    it "belongs_to :scene as optional" do
      scene = create(:scene)
      llm_call = create(:llm_call, scene: scene)
      expect(llm_call.scene).to eq(scene)
    end

    it "nullifies scene_id when the scene is deleted at the DB level" do
      scene = create(:scene)
      llm_call = create(:llm_call, scene: scene)
      ActiveRecord::Base.connection.execute("DELETE FROM scenes WHERE id = #{scene.id}")
      expect(llm_call.reload.scene_id).to be_nil
    end
  end
```

If the existing `LlmCall` factory does not accept a `scene` association, also check `spec/factories/llm_calls.rb`. If it lacks an explicit `scene` attribute, no change is needed — Factory Bot will accept `scene: scene` as an attribute override.

- [ ] **Step 4: Run the failing spec**

Run: `bundle exec rspec spec/models/llm_call_spec.rb`
Expected: failure with `NoMethodError: undefined method 'scene' for #<LlmCall>` (or `Module#prepend ... NoMethodError`).

- [ ] **Step 5: Uncomment `belongs_to :scene` in LlmCall**

Edit `app/models/llm_call.rb`. Locate the line:

```ruby
  # belongs_to :scene, optional: true  # uncomment in Phase 5 when Scene model exists
```

Replace it with:

```ruby
  belongs_to :scene, optional: true
```

- [ ] **Step 6: Run the spec to verify it passes**

Run: `bundle exec rspec spec/models/llm_call_spec.rb`
Expected: green.

- [ ] **Step 7: Add a `has_many :llm_calls` reverse on Scene**

Edit `app/models/scene.rb` so it reads:

```ruby
class Scene < ApplicationRecord
  belongs_to :campaign
  has_many :events, dependent: :destroy
  has_many :llm_calls, dependent: :nullify

  acts_as_list scope: :campaign

  validates :title, presence: true, length: { maximum: 100 }
end
```

`dependent: :nullify` matches the DB-level `on_delete: :nullify` so Rails-mediated deletions behave consistently.

- [ ] **Step 8: Add a Scene-side spec example**

Edit `spec/models/scene_spec.rb`. Inside the existing `describe "associations"` block, add:

```ruby
    it { is_expected.to have_many(:events).dependent(:destroy) }
    it { is_expected.to have_many(:llm_calls).dependent(:nullify) }
```

- [ ] **Step 9: Run the suite**

Run: `bundle exec rspec`
Expected: green overall.

- [ ] **Step 10: Commit**

```bash
git add db/migrate db/schema.rb app/models/llm_call.rb app/models/scene.rb spec/models/llm_call_spec.rb spec/models/scene_spec.rb
git commit -m "Wire LlmCall <-> Scene foreign key and associations (Phase 5.8)"
```

---

## Task 9: `ApplicationViewModel` base + `expose` DSL + recursive `to_h`

**Files:**
- Create: `app/view_models/application_view_model.rb`
- Create: `spec/view_models/application_view_model_spec.rb`

- [ ] **Step 1: Write a failing spec for the attr-list form of `expose`**

Create `spec/view_models/application_view_model_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe ApplicationViewModel, type: :view_model do
  let(:record_class) do
    Struct.new(:name, :email, :secret, keyword_init: true)
  end

  let(:record) { record_class.new(name: "Ada", email: "ada@example.test", secret: "hidden") }

  describe "attr-list expose" do
    let(:vm_class) do
      Class.new(described_class) do
        expose :name, :email
      end
    end

    it "auto-defines readers that delegate to the record" do
      vm = vm_class.new(record)
      expect(vm.name).to eq("Ada")
      expect(vm.email).to eq("ada@example.test")
    end

    it "records exposed attrs on the class" do
      expect(vm_class.exposed_attrs).to eq([:name, :email])
    end

    it "does NOT expose attrs that weren't declared" do
      vm = vm_class.new(record)
      expect { vm.secret }.to raise_error(NoMethodError)
    end
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/view_models/application_view_model_spec.rb`
Expected: failure with `NameError: uninitialized constant ApplicationViewModel`.

- [ ] **Step 3: Implement the minimal base class**

Create `app/view_models/application_view_model.rb`:

```ruby
class ApplicationViewModel
  class << self
    def expose(*attrs)
      attrs.each do |attr|
        define_method(attr) { @record.public_send(attr) }
        record_exposed(attr)
      end
    end

    def exposed_attrs
      (@exposed_attrs || []).dup.freeze
    end

    private

    def record_exposed(attr)
      @exposed_attrs = (@exposed_attrs || []) + [attr]
    end
  end

  def initialize(record)
    @record = record
  end
end
```

- [ ] **Step 4: Run the spec to verify it passes**

Run: `bundle exec rspec spec/view_models/application_view_model_spec.rb`
Expected: green.

- [ ] **Step 5: Add a failing spec for the block form of `expose`**

Append to `spec/view_models/application_view_model_spec.rb`, inside the top-level `RSpec.describe` block:

```ruby
  describe "block-form expose" do
    let(:vm_class) do
      Class.new(described_class) do
        expose :name
        expose :greeting do
          "Hello, #{@record.name}"
        end
      end
    end

    it "defines the reader from the block" do
      vm = vm_class.new(record)
      expect(vm.greeting).to eq("Hello, Ada")
    end

    it "records the block-form attr in exposed_attrs" do
      expect(vm_class.exposed_attrs).to eq([:name, :greeting])
    end

    it "raises if a block is given with multiple attr names" do
      expect {
        Class.new(described_class) do
          expose(:foo, :bar) { 42 }
        end
      }.to raise_error(ArgumentError, /exactly one attr name/)
    end
  end
```

- [ ] **Step 6: Run the spec to verify it fails**

Run: `bundle exec rspec spec/view_models/application_view_model_spec.rb`
Expected: failure on the new block-form examples (the current `expose` ignores blocks).

- [ ] **Step 7: Extend `expose` to accept a block**

Edit `app/view_models/application_view_model.rb`. Replace the `expose` method body so the class reads:

```ruby
class ApplicationViewModel
  class << self
    def expose(*attrs, &block)
      if block
        raise ArgumentError, "expose with a block requires exactly one attr name" unless attrs.size == 1
        attr = attrs.first
        define_method(attr, &block)
        record_exposed(attr)
      else
        attrs.each do |attr|
          define_method(attr) { @record.public_send(attr) }
          record_exposed(attr)
        end
      end
    end

    def exposed_attrs
      (@exposed_attrs || []).dup.freeze
    end

    private

    def record_exposed(attr)
      @exposed_attrs = (@exposed_attrs || []) + [attr]
    end
  end

  def initialize(record)
    @record = record
  end
end
```

- [ ] **Step 8: Run the spec to verify it passes**

Run: `bundle exec rspec spec/view_models/application_view_model_spec.rb`
Expected: green.

- [ ] **Step 9: Add a failing spec for `to_h`**

Append to `spec/view_models/application_view_model_spec.rb`:

```ruby
  describe "#to_h" do
    let(:vm_class) do
      Class.new(described_class) do
        expose :name, :email
      end
    end

    it "returns a hash of exposed attrs and their values" do
      vm = vm_class.new(record)
      expect(vm.to_h).to eq(name: "Ada", email: "ada@example.test")
    end

    it "recursively unwraps nested ViewModels" do
      inner_class = Class.new(described_class) { expose :name }
      outer_class = Class.new(described_class) do
        nested = inner_class
        expose :friend do
          nested.new(@record.friend)
        end
      end

      friend_record = record_class.new(name: "Grace", email: nil, secret: nil)
      record_with_friend = Struct.new(:friend, keyword_init: true).new(friend: friend_record)

      vm = outer_class.new(record_with_friend)
      expect(vm.to_h).to eq(friend: { name: "Grace" })
    end

    it "recursively unwraps arrays of nested ViewModels" do
      inner_class = Class.new(described_class) { expose :name }
      outer_class = Class.new(described_class) do
        nested = inner_class
        expose :friends do
          @record.friends.map { |f| nested.new(f) }
        end
      end

      friends = [
        record_class.new(name: "Grace", email: nil, secret: nil),
        record_class.new(name: "Linus", email: nil, secret: nil),
      ]
      record_with_friends = Struct.new(:friends, keyword_init: true).new(friends: friends)

      vm = outer_class.new(record_with_friends)
      expect(vm.to_h).to eq(friends: [{ name: "Grace" }, { name: "Linus" }])
    end
  end
```

- [ ] **Step 10: Run the spec to verify it fails**

Run: `bundle exec rspec spec/view_models/application_view_model_spec.rb`
Expected: failure on the `#to_h` examples (no `to_h` defined).

- [ ] **Step 11: Implement `to_h` with recursive rendering**

Edit `app/view_models/application_view_model.rb`. Append `to_h` and `render_value` to the instance section:

```ruby
class ApplicationViewModel
  class << self
    def expose(*attrs, &block)
      if block
        raise ArgumentError, "expose with a block requires exactly one attr name" unless attrs.size == 1
        attr = attrs.first
        define_method(attr, &block)
        record_exposed(attr)
      else
        attrs.each do |attr|
          define_method(attr) { @record.public_send(attr) }
          record_exposed(attr)
        end
      end
    end

    def exposed_attrs
      (@exposed_attrs || []).dup.freeze
    end

    private

    def record_exposed(attr)
      @exposed_attrs = (@exposed_attrs || []) + [attr]
    end
  end

  def initialize(record)
    @record = record
  end

  def to_h
    self.class.exposed_attrs.each_with_object({}) do |attr, h|
      h[attr] = render_value(public_send(attr))
    end
  end

  private

  def render_value(value)
    case value
    when ApplicationViewModel then value.to_h
    when Array                then value.map { |v| render_value(v) }
    else                           value
    end
  end
end
```

- [ ] **Step 12: Run the spec to verify it passes**

Run: `bundle exec rspec spec/view_models/application_view_model_spec.rb`
Expected: green on all examples.

- [ ] **Step 13: Run the full suite**

Run: `bundle exec rspec`
Expected: green overall.

- [ ] **Step 14: Commit**

```bash
git add app/view_models/application_view_model.rb spec/view_models/application_view_model_spec.rb
git commit -m "Add ApplicationViewModel base with expose DSL and recursive to_h (Phase 5.9)"
```

---

## Task 10: `leak_secrets_of` matcher

**Files:**
- Create: `spec/support/matchers/not_to_leak.rb`
- Create: `spec/support/matchers/not_to_leak_spec.rb`

**Context.** The matcher file `not_to_leak.rb` will house BOTH `leak_secrets_of` (this task) and `expose_attrs_via` (Task 11). The filename follows Phase 0's "not_to_leak" phrasing and serves as the entrypoint for the asymmetry-test infrastructure.

- [ ] **Step 1: Write the failing matcher spec (string subject)**

Create `spec/support/matchers/not_to_leak_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "leak_secrets_of matcher" do
  let(:campaign) { create(:campaign) }
  let(:faction)  { create(:faction, campaign: campaign) }

  describe "with a String subject" do
    it "matches when the string contains a secret's content" do
      create(:faction_secret, faction: faction, content: "the hidden temple is in the swamp")
      expect("Some text mentioning the hidden temple is in the swamp.").to leak_secrets_of(faction)
    end

    it "matches when the string contains a secret's label" do
      create(:faction_secret, faction: faction, label: "true leader identity", content: "irrelevant")
      expect("This text mentions the true leader identity in passing.").to leak_secrets_of(faction)
    end

    it "does NOT match when the string contains no secret content or label" do
      create(:faction_secret, faction: faction, label: "hidden temple", content: "in the swamp")
      expect("This text is innocuous and reveals nothing.").not_to leak_secrets_of(faction)
    end

    it "does NOT match when the faction has no secrets at all" do
      # No secrets created.
      expect("Any string here.").not_to leak_secrets_of(faction)
    end
  end

  describe "with multiple records" do
    let(:npc) { create(:npc, campaign: campaign) }

    it "collects secrets across all records" do
      create(:faction_secret, faction: faction, content: "faction secret content")
      create(:npc_secret,     npc: npc,         content: "npc secret content")

      expect("This leaks faction secret content.").to     leak_secrets_of(faction, npc)
      expect("This leaks npc secret content.").to         leak_secrets_of(faction, npc)
      expect("This text is innocuous.").not_to            leak_secrets_of(faction, npc)
    end
  end

  describe "failure message" do
    it "names the secret that leaked" do
      create(:faction_secret, faction: faction, content: "the hidden temple")
      matcher = leak_secrets_of(faction)
      matcher.matches?("This mentions the hidden temple.")
      expect(matcher.failure_message_when_negated).to include("the hidden temple")
    end
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/support/matchers/not_to_leak_spec.rb`
Expected: failure with `NoMethodError: undefined method 'leak_secrets_of'`.

- [ ] **Step 3: Implement the matcher (string subject case)**

Create `spec/support/matchers/not_to_leak.rb`:

```ruby
# spec/support/matchers/not_to_leak.rb
#
# Asymmetry test matchers.
#
# leak_secrets_of(*records)
#   Asserts that a subject (a String, or any object responding to #to_h) does
#   not contain any `label` or `content` value from the `secrets` association
#   of the provided records. Use it like:
#
#     expect(player_view_model).not_to leak_secrets_of(faction)
#     expect(rendered_prompt).not_to    leak_secrets_of(faction, npc)
#
# expose_attrs_via(association_name)
#   Asserts (as a structural check) that a ViewModel class exposes an
#   attribute whose name matches the given association. Use it like:
#
#     expect(Player::FactionViewModel).not_to expose_attrs_via(:secrets)
#
# The matchers are complementary: leak_secrets_of catches dynamic leaks
# (including ones disguised behind differently-named exposed attrs);
# expose_attrs_via catches the structural shape "you exposed :secrets" even
# when no secret content happens to exist in the test fixture.

RSpec::Matchers.define :leak_secrets_of do |*records|
  match do |subject|
    @leaked = []
    collect_secret_strings(records).each do |secret_str|
      next if secret_str.nil? || secret_str.empty?
      if render_subject(subject).include?(secret_str)
        @leaked << secret_str
      end
    end
    @leaked.any?
  end

  failure_message do |subject|
    "expected subject to leak secrets of #{records.map(&:class).join(', ')}, but found none"
  end

  failure_message_when_negated do |subject|
    "expected subject NOT to leak secrets, but found these leaked strings: #{@leaked.inspect}"
  end

  def collect_secret_strings(records)
    records.flat_map do |r|
      next [] unless r.respond_to?(:secrets)
      r.secrets.flat_map { |s| [s.label, s.content] }
    end
  end

  def render_subject(subject)
    return subject if subject.is_a?(String)
    return deep_stringify(subject.to_h) if subject.respond_to?(:to_h)
    subject.to_s
  end

  def deep_stringify(value)
    case value
    when Hash  then value.flat_map { |k, v| [k.to_s, deep_stringify(v)] }.join(" ")
    when Array then value.map { |v| deep_stringify(v) }.join(" ")
    when nil   then ""
    else            value.to_s
    end
  end
end
```

- [ ] **Step 4: Run the spec to verify the string-subject examples pass**

Run: `bundle exec rspec spec/support/matchers/not_to_leak_spec.rb`
Expected: green on all string-subject examples.

- [ ] **Step 5: Add a failing spec for ViewModel subjects**

Append to `spec/support/matchers/not_to_leak_spec.rb`:

```ruby
  describe "with a ViewModel subject (via to_h)" do
    let(:safe_vm_class) do
      Class.new(ApplicationViewModel) { expose :name }
    end

    let(:leaky_vm_class) do
      Class.new(ApplicationViewModel) do
        expose :name
        expose :everything do
          @record.secrets.map { |s| s.content }
        end
      end
    end

    it "does NOT match a ViewModel that only exposes public attrs" do
      create(:faction_secret, faction: faction, content: "hidden")
      vm = safe_vm_class.new(faction)
      expect(vm).not_to leak_secrets_of(faction)
    end

    it "matches a ViewModel that exposes a secret-traversing attr" do
      create(:faction_secret, faction: faction, content: "the hidden temple")
      vm = leaky_vm_class.new(faction)
      expect(vm).to leak_secrets_of(faction)
    end
  end
```

- [ ] **Step 6: Run the spec**

Run: `bundle exec rspec spec/support/matchers/not_to_leak_spec.rb`
Expected: green on all examples (the matcher already handles `to_h`-responding subjects).

- [ ] **Step 7: Run the full suite**

Run: `bundle exec rspec`
Expected: green overall.

- [ ] **Step 8: Commit**

```bash
git add spec/support/matchers/not_to_leak.rb spec/support/matchers/not_to_leak_spec.rb
git commit -m "Add leak_secrets_of asymmetry matcher (Phase 5.10)"
```

---

## Task 11: `expose_attrs_via` matcher

**Files:**
- Modify: `spec/support/matchers/not_to_leak.rb`
- Modify: `spec/support/matchers/not_to_leak_spec.rb`

- [ ] **Step 1: Write a failing spec for the structural matcher**

Append to `spec/support/matchers/not_to_leak_spec.rb`:

```ruby
RSpec.describe "expose_attrs_via matcher" do
  let(:player_vm_class) do
    Class.new(ApplicationViewModel) { expose :id, :name }
  end

  let(:narrator_vm_class) do
    Class.new(ApplicationViewModel) do
      expose :id, :name
      expose :secrets do
        []
      end
    end
  end

  let(:disguised_leaker_class) do
    Class.new(ApplicationViewModel) do
      expose :hidden_facts do
        @record.secrets.map(&:content)
      end
    end
  end

  it "matches a class with :secrets in exposed_attrs" do
    expect(narrator_vm_class).to expose_attrs_via(:secrets)
  end

  it "does NOT match a class whose exposed_attrs excludes :secrets" do
    expect(player_vm_class).not_to expose_attrs_via(:secrets)
  end

  it "documented limitation: does NOT match a disguised leaker (caught dynamically by leak_secrets_of)" do
    expect(disguised_leaker_class).not_to expose_attrs_via(:secrets)
    # And here's the dynamic catch:
    campaign = create(:campaign)
    faction = create(:faction, campaign: campaign)
    create(:faction_secret, faction: faction, content: "leaked content")
    vm = disguised_leaker_class.new(faction)
    expect(vm).to leak_secrets_of(faction)
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/support/matchers/not_to_leak_spec.rb`
Expected: failure with `NoMethodError: undefined method 'expose_attrs_via'`.

- [ ] **Step 3: Implement the matcher**

Append to `spec/support/matchers/not_to_leak.rb` (below the `leak_secrets_of` definition):

```ruby
RSpec::Matchers.define :expose_attrs_via do |association_name|
  match do |view_model_class|
    view_model_class.respond_to?(:exposed_attrs) &&
      view_model_class.exposed_attrs.include?(association_name)
  end

  failure_message do |klass|
    "expected #{klass} to expose attrs via #{association_name.inspect}, but exposed_attrs is #{klass.exposed_attrs.inspect}"
  end

  failure_message_when_negated do |klass|
    "expected #{klass} NOT to expose attrs via #{association_name.inspect}, but :#{association_name} is in exposed_attrs"
  end
end
```

- [ ] **Step 4: Run the spec to verify it passes**

Run: `bundle exec rspec spec/support/matchers/not_to_leak_spec.rb`
Expected: green on all examples.

- [ ] **Step 5: Run the full suite**

Run: `bundle exec rspec`
Expected: green overall.

- [ ] **Step 6: Commit**

```bash
git add spec/support/matchers/not_to_leak.rb spec/support/matchers/not_to_leak_spec.rb
git commit -m "Add expose_attrs_via structural matcher (Phase 5.11)"
```

---

## Task 12: Player ViewModels (Faction + Npc)

**Files:**
- Create: `app/view_models/player/faction_view_model.rb`
- Create: `app/view_models/player/npc_view_model.rb`
- Create: `spec/view_models/player/faction_view_model_spec.rb`
- Create: `spec/view_models/player/npc_view_model_spec.rb`

- [ ] **Step 1: Write the failing spec for `Player::FactionViewModel`**

Create `spec/view_models/player/faction_view_model_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Player::FactionViewModel, type: :view_model do
  let(:campaign) { create(:campaign) }
  let(:faction)  { create(:faction, campaign: campaign, name: "The Cult", public_description: "A shadowy group") }
  let(:vm)       { described_class.new(faction) }

  describe "exposed attrs" do
    it { expect(described_class.exposed_attrs).to eq([:id, :name, :public_description]) }
  end

  describe "values" do
    it "returns id, name, and public_description from the record" do
      expect(vm.id).to eq(faction.id)
      expect(vm.name).to eq("The Cult")
      expect(vm.public_description).to eq("A shadowy group")
    end
  end

  describe "structural asymmetry" do
    it "does not expose :secrets" do
      expect(described_class).not_to expose_attrs_via(:secrets)
    end

    it "does not respond to #secrets" do
      expect(vm).not_to respond_to(:secrets)
    end
  end

  describe "dynamic asymmetry (not_to_leak)" do
    before do
      create(:faction_secret, faction: faction, label: "hidden temple", content: "in the swamp")
      create(:faction_secret, faction: faction, label: "true leader",   content: "is the mayor")
    end

    it "does not leak secrets of the faction" do
      expect(vm).not_to leak_secrets_of(faction)
    end
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/view_models/player/faction_view_model_spec.rb`
Expected: failure with `NameError: uninitialized constant Player::FactionViewModel`.

- [ ] **Step 3: Write the Player::FactionViewModel**

Create `app/view_models/player/faction_view_model.rb`:

```ruby
module Player
  class FactionViewModel < ApplicationViewModel
    expose :id, :name, :public_description
  end
end
```

- [ ] **Step 4: Run the spec to verify it passes**

Run: `bundle exec rspec spec/view_models/player/faction_view_model_spec.rb`
Expected: green.

- [ ] **Step 5: Write the failing spec for `Player::NpcViewModel`**

Create `spec/view_models/player/npc_view_model_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Player::NpcViewModel, type: :view_model do
  let(:campaign) { create(:campaign) }
  let(:npc)      { create(:npc, campaign: campaign, name: "John", public_description: "A villager", location: "The town square") }
  let(:vm)       { described_class.new(npc) }

  describe "exposed attrs" do
    it { expect(described_class.exposed_attrs).to eq([:id, :name, :public_description, :location]) }
  end

  describe "values" do
    it "returns id, name, public_description, and location from the record" do
      expect(vm.id).to eq(npc.id)
      expect(vm.name).to eq("John")
      expect(vm.public_description).to eq("A villager")
      expect(vm.location).to eq("The town square")
    end
  end

  describe "structural asymmetry" do
    it "does not expose :secrets" do
      expect(described_class).not_to expose_attrs_via(:secrets)
    end

    it "does not respond to #secrets" do
      expect(vm).not_to respond_to(:secrets)
    end
  end

  describe "dynamic asymmetry (not_to_leak)" do
    before do
      create(:npc_secret, npc: npc, label: "true identity", content: "is a doppelganger")
    end

    it "does not leak secrets of the npc" do
      expect(vm).not_to leak_secrets_of(npc)
    end
  end
end
```

- [ ] **Step 6: Run the spec to verify it fails**

Run: `bundle exec rspec spec/view_models/player/npc_view_model_spec.rb`
Expected: failure with `NameError: uninitialized constant Player::NpcViewModel`.

- [ ] **Step 7: Write the Player::NpcViewModel**

Create `app/view_models/player/npc_view_model.rb`:

```ruby
module Player
  class NpcViewModel < ApplicationViewModel
    expose :id, :name, :public_description, :location
  end
end
```

- [ ] **Step 8: Run the spec to verify it passes**

Run: `bundle exec rspec spec/view_models/player/npc_view_model_spec.rb`
Expected: green.

- [ ] **Step 9: Run the full suite**

Run: `bundle exec rspec`
Expected: green overall.

- [ ] **Step 10: Commit**

```bash
git add app/view_models/player spec/view_models/player
git commit -m "Add Player ViewModels for Faction and Npc (Phase 5.12)"
```

---

## Task 13: Narrator ViewModels for Faction + FactionSecret

**Files:**
- Create: `app/view_models/narrator/faction_secret_view_model.rb`
- Create: `app/view_models/narrator/faction_view_model.rb`
- Create: `spec/view_models/narrator/faction_secret_view_model_spec.rb`
- Create: `spec/view_models/narrator/faction_view_model_spec.rb`

- [ ] **Step 1: Write the failing spec for `Narrator::FactionSecretViewModel`**

Create `spec/view_models/narrator/faction_secret_view_model_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Narrator::FactionSecretViewModel, type: :view_model do
  let(:faction) { create(:faction) }
  let(:secret)  { create(:faction_secret, faction: faction, label: "hidden temple", content: "in the swamp") }
  let(:vm)      { described_class.new(secret) }

  describe "exposed attrs" do
    it { expect(described_class.exposed_attrs).to eq([:id, :label, :content]) }
  end

  describe "values" do
    it "returns id, label, and content" do
      expect(vm.id).to eq(secret.id)
      expect(vm.label).to eq("hidden temple")
      expect(vm.content).to eq("in the swamp")
    end
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/view_models/narrator/faction_secret_view_model_spec.rb`
Expected: failure with `NameError: uninitialized constant Narrator::FactionSecretViewModel`.

- [ ] **Step 3: Write the Narrator::FactionSecretViewModel**

Create `app/view_models/narrator/faction_secret_view_model.rb`:

```ruby
module Narrator
  class FactionSecretViewModel < ApplicationViewModel
    expose :id, :label, :content
  end
end
```

- [ ] **Step 4: Run the spec to verify it passes**

Run: `bundle exec rspec spec/view_models/narrator/faction_secret_view_model_spec.rb`
Expected: green.

- [ ] **Step 5: Write the failing spec for `Narrator::FactionViewModel`**

Create `spec/view_models/narrator/faction_view_model_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Narrator::FactionViewModel, type: :view_model do
  let(:campaign) { create(:campaign) }
  let(:faction)  { create(:faction, campaign: campaign, name: "The Cult", public_description: "A shadowy group") }
  let(:vm)       { described_class.new(faction) }

  before do
    create(:faction_secret, faction: faction, label: "hidden temple", content: "in the swamp")
    create(:faction_secret, faction: faction, label: "true leader",   content: "is the mayor")
  end

  describe "exposed attrs" do
    it "exposes the public set plus secrets" do
      expect(described_class.exposed_attrs).to eq([:id, :name, :public_description, :secrets])
    end
  end

  describe "values" do
    it "returns id, name, public_description from the record" do
      expect(vm.id).to eq(faction.id)
      expect(vm.name).to eq("The Cult")
      expect(vm.public_description).to eq("A shadowy group")
    end

    it "wraps secrets in Narrator::FactionSecretViewModel" do
      expect(vm.secrets).to all(be_a(Narrator::FactionSecretViewModel))
      expect(vm.secrets.map(&:label)).to contain_exactly("hidden temple", "true leader")
      expect(vm.secrets.map(&:content)).to contain_exactly("in the swamp", "is the mayor")
    end
  end

  describe "structural asymmetry (positive)" do
    it "is documented as exposing secrets" do
      expect(described_class).to expose_attrs_via(:secrets)
    end
  end

  describe "dynamic asymmetry (positive, symmetric matcher demonstration)" do
    it "DOES leak the secrets of its faction (by design — narrator-side)" do
      expect(vm).to leak_secrets_of(faction)
    end
  end
end
```

- [ ] **Step 6: Run the spec to verify it fails**

Run: `bundle exec rspec spec/view_models/narrator/faction_view_model_spec.rb`
Expected: failure with `NameError: uninitialized constant Narrator::FactionViewModel`.

- [ ] **Step 7: Write the Narrator::FactionViewModel**

Create `app/view_models/narrator/faction_view_model.rb`:

```ruby
module Narrator
  class FactionViewModel < ApplicationViewModel
    expose :id, :name, :public_description

    expose :secrets do
      @record.secrets.map { |s| Narrator::FactionSecretViewModel.new(s) }
    end
  end
end
```

- [ ] **Step 8: Run the spec to verify it passes**

Run: `bundle exec rspec spec/view_models/narrator/faction_view_model_spec.rb`
Expected: green.

- [ ] **Step 9: Run the full suite**

Run: `bundle exec rspec`
Expected: green overall.

- [ ] **Step 10: Commit**

```bash
git add app/view_models/narrator/faction_secret_view_model.rb app/view_models/narrator/faction_view_model.rb spec/view_models/narrator/faction_secret_view_model_spec.rb spec/view_models/narrator/faction_view_model_spec.rb
git commit -m "Add Narrator ViewModels for Faction (and FactionSecret) (Phase 5.13)"
```

---

## Task 14: Narrator ViewModels for Npc + NpcSecret

**Files:**
- Create: `app/view_models/narrator/npc_secret_view_model.rb`
- Create: `app/view_models/narrator/npc_view_model.rb`
- Create: `spec/view_models/narrator/npc_secret_view_model_spec.rb`
- Create: `spec/view_models/narrator/npc_view_model_spec.rb`

- [ ] **Step 1: Write the failing spec for `Narrator::NpcSecretViewModel`**

Create `spec/view_models/narrator/npc_secret_view_model_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Narrator::NpcSecretViewModel, type: :view_model do
  let(:npc)    { create(:npc) }
  let(:secret) { create(:npc_secret, npc: npc, label: "true identity", content: "is a doppelganger") }
  let(:vm)     { described_class.new(secret) }

  describe "exposed attrs" do
    it { expect(described_class.exposed_attrs).to eq([:id, :label, :content]) }
  end

  describe "values" do
    it "returns id, label, and content" do
      expect(vm.id).to eq(secret.id)
      expect(vm.label).to eq("true identity")
      expect(vm.content).to eq("is a doppelganger")
    end
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/view_models/narrator/npc_secret_view_model_spec.rb`
Expected: failure with `NameError: uninitialized constant Narrator::NpcSecretViewModel`.

- [ ] **Step 3: Write the Narrator::NpcSecretViewModel**

Create `app/view_models/narrator/npc_secret_view_model.rb`:

```ruby
module Narrator
  class NpcSecretViewModel < ApplicationViewModel
    expose :id, :label, :content
  end
end
```

- [ ] **Step 4: Run the spec to verify it passes**

Run: `bundle exec rspec spec/view_models/narrator/npc_secret_view_model_spec.rb`
Expected: green.

- [ ] **Step 5: Write the failing spec for `Narrator::NpcViewModel`**

Create `spec/view_models/narrator/npc_view_model_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Narrator::NpcViewModel, type: :view_model do
  let(:campaign) { create(:campaign) }
  let(:npc)      { create(:npc, campaign: campaign, name: "John", public_description: "A villager", location: "The town square") }
  let(:vm)       { described_class.new(npc) }

  before do
    create(:npc_secret, npc: npc, label: "true identity", content: "is a doppelganger")
  end

  describe "exposed attrs" do
    it "exposes the public set plus secrets" do
      expect(described_class.exposed_attrs).to eq([:id, :name, :public_description, :location, :secrets])
    end
  end

  describe "values" do
    it "returns id, name, public_description, location from the record" do
      expect(vm.id).to eq(npc.id)
      expect(vm.name).to eq("John")
      expect(vm.public_description).to eq("A villager")
      expect(vm.location).to eq("The town square")
    end

    it "wraps secrets in Narrator::NpcSecretViewModel" do
      expect(vm.secrets).to all(be_a(Narrator::NpcSecretViewModel))
      expect(vm.secrets.map(&:label)).to eq(["true identity"])
      expect(vm.secrets.map(&:content)).to eq(["is a doppelganger"])
    end
  end

  describe "structural asymmetry (positive)" do
    it "is documented as exposing secrets" do
      expect(described_class).to expose_attrs_via(:secrets)
    end
  end

  describe "dynamic asymmetry (positive, symmetric matcher demonstration)" do
    it "DOES leak the secrets of its npc (by design — narrator-side)" do
      expect(vm).to leak_secrets_of(npc)
    end
  end
end
```

- [ ] **Step 6: Run the spec to verify it fails**

Run: `bundle exec rspec spec/view_models/narrator/npc_view_model_spec.rb`
Expected: failure with `NameError: uninitialized constant Narrator::NpcViewModel`.

- [ ] **Step 7: Write the Narrator::NpcViewModel**

Create `app/view_models/narrator/npc_view_model.rb`:

```ruby
module Narrator
  class NpcViewModel < ApplicationViewModel
    expose :id, :name, :public_description, :location

    expose :secrets do
      @record.secrets.map { |s| Narrator::NpcSecretViewModel.new(s) }
    end
  end
end
```

- [ ] **Step 8: Run the spec to verify it passes**

Run: `bundle exec rspec spec/view_models/narrator/npc_view_model_spec.rb`
Expected: green.

- [ ] **Step 9: Run the full suite**

Run: `bundle exec rspec`
Expected: green overall.

- [ ] **Step 10: Commit**

```bash
git add app/view_models/narrator/npc_secret_view_model.rb app/view_models/narrator/npc_view_model.rb spec/view_models/narrator/npc_secret_view_model_spec.rb spec/view_models/narrator/npc_view_model_spec.rb
git commit -m "Add Narrator ViewModels for Npc (and NpcSecret) (Phase 5.14)"
```

---

## Task 15: Final pass — annotaterb, RuboCop, ERB lint, acceptance check

**Files:**
- Modify: `app/models/*.rb` (annotation headers)
- Modify: `spec/factories/*.rb` (annotation headers)

- [ ] **Step 1: Run annotaterb**

Run: `bundle exec annotaterb models`
Expected: schema-info headers appear (or refresh) at the top of every new model file (`faction.rb`, `faction_secret.rb`, `npc.rb`, `npc_secret.rb`, `scene.rb`, `event.rb`) and at the top of every new factory file (`factories/factions.rb`, `factories/faction_secrets.rb`, `factories/npcs.rb`, `factories/npc_secrets.rb`, `factories/scenes.rb`, `factories/events.rb`). Existing models (`user.rb`, `campaign.rb`, `llm_call.rb`) may have minor refreshes if their schema annotations were out of date.

Inspect the diff:

```bash
git diff app/models spec/factories
```

Confirm the headers match the migrations.

- [ ] **Step 2: Run the full test suite**

Run: `bundle exec rspec`
Expected: green. Count examples — there should now be roughly:
- 6 model specs (Faction, FactionSecret, Npc, NpcSecret, Scene, Event)
- 4 ViewModel specs (Player Faction, Player Npc, Narrator Faction, Narrator Npc)
- 2 secret-VM specs (Narrator FactionSecret, Narrator NpcSecret)
- 1 base VM spec (ApplicationViewModel)
- 1 matcher spec (combined `leak_secrets_of` + `expose_attrs_via`)
- Pre-existing Phase 1–4 specs (Campaign, User, LlmCall, components, requests, etc.)

- [ ] **Step 3: Run RuboCop**

Run: `bundle exec rubocop`
Expected: no offenses on the newly added files. If RuboCop flags style issues (typically: `Style/FrozenStringLiteralComment`, alignment, etc.), apply `bundle exec rubocop -A` for safe autocorrects and re-run.

- [ ] **Step 4: Run erb_lint**

Run: `bundle exec erb_lint --lint-all`
Expected: no offenses (Phase 5 added no `.erb` files). This is a regression guard against the unrelated working-tree changes that may be pending.

- [ ] **Step 5: Acceptance criteria walkthrough**

Verify each acceptance criterion from issue #6:

- [ ] Migrations create all six tables (factions, faction_secrets, npcs, npc_secrets, scenes, events) with FKs, indexes, and `belongs_to :campaign` scoping. Check: `db/schema.rb` shows all six tables and the cascade FKs.
- [ ] `Player::FactionViewModel` exposes only public fields; spec asserts via `not_to leak_secrets_of`. Check: `spec/view_models/player/faction_view_model_spec.rb` green.
- [ ] `Narrator::FactionViewModel` exposes everything; spec asserts it. Check: `spec/view_models/narrator/faction_view_model_spec.rb` green.
- [ ] The `not_to_leak` custom matcher exists and is documented in `spec/support/matchers/`. Check: `spec/support/matchers/not_to_leak.rb` exists with top-of-file docstring covering both matchers.
- [ ] Same pattern verified for `Npc`. Check: `spec/view_models/player/npc_view_model_spec.rb` and `spec/view_models/narrator/npc_view_model_spec.rb` green.
- [ ] Event model supports the polymorphic kinds. Check: `spec/models/event_spec.rb` enum round-trip examples green for all four kinds.

- [ ] **Step 6: Commit annotation refreshes**

```bash
git add app/models spec/factories
git commit -m "Refresh annotaterb headers across Phase 5 models and factories (Phase 5.15)"
```

If `git status` shows nothing to commit (all headers were already in place from earlier tasks), skip this step and proceed.

- [ ] **Step 7: Final sanity check**

Run:

```bash
git status
git log --oneline -20
bundle exec rspec
```

Expected: clean working tree (except for any unrelated Phase-6-prep changes in `app/components/`, `app/views/layouts/`, `app/javascript/`, etc. that were present at the start of the branch); 14 Phase 5 commits in the log; green test suite.

Phase 5 is done.
