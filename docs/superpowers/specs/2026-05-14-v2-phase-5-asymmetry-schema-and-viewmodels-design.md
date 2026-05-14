# v2 Phase 5 — Asymmetry schema + ViewModels + test infrastructure

Date: 2026-05-14
Status: Design spec. Drives the writing-plans pass for Phase 5.
Issue: [#6](https://github.com/barriault/gygaxagain/issues/6)
Parent roadmap: [`2026-05-13-v2-phase-0-roadmap-design.md`](2026-05-13-v2-phase-0-roadmap-design.md)
Prior phase: [`2026-05-14-v2-phase-4-llm-provider-and-anthropic-adapter-design.md`](2026-05-14-v2-phase-4-llm-provider-and-anthropic-adapter-design.md)

## Scope

Introduce the load-bearing data layer for asymmetric play. Six tables — `factions`, `faction_secrets`, `npcs`, `npc_secrets`, `scenes`, `events` — all rooted at `Campaign`. ViewModels under `app/view_models/player/` and `app/view_models/narrator/` for the two asymmetric models (`Faction`, `Npc`), with a thin `ApplicationViewModel` base providing an `expose` DSL. A custom RSpec matcher pair (`leak_secrets_of` and `expose_attrs_via`) at `spec/support/matchers/not_to_leak.rb`, used to assert asymmetry properties of ViewModels (Phase 5) and, in later phases, of prompt strings and rendered components.

No controllers, no routes, no views, no ViewComponents, no service objects. Phase 5 is bare schema + ViewModels + test infrastructure.

## Dependencies

Phase 3 ([#4](https://github.com/barriault/gygaxagain/issues/4)) complete: `Campaign` model exists with `belongs_to :user` and `on_delete: :cascade`. Phase 4 ([#5](https://github.com/barriault/gygaxagain/issues/5)) is not a dependency — Phase 5 has no LLM touchpoints. Phases 3 and 5 are independently mergeable in principle, but in practice Phase 4 landed first.

## Acceptance criteria

Verbatim from the GitHub issue:

- Migrations create all six tables (factions, faction_secrets, npcs, npc_secrets, scenes, events) with appropriate foreign keys, indexes, and `belongs_to :campaign` scoping.
- `Player::FactionViewModel` exposes only public fields; spec asserts it via `not_to_leak`.
- `Narrator::FactionViewModel` exposes everything; spec asserts it.
- The `not_to_leak` custom matcher exists and is documented in `spec/support/matchers/`.
- Same pattern verified for `Npc`.
- Event model supports the polymorphic kinds: narration, dice_roll, oracle_query, scene_transition (more kinds added in later phases as needed).

## Architectural commitments inherited from Phase 0

Phase 0 locks the asymmetry-model and multi-tenancy decisions. This spec applies them; it does not re-litigate them.

- **Asymmetry-by-context-construction.** Hidden state lives in separate `*_secrets` tables. Player-facing code paths cannot reach hidden state because the access path doesn't exist in the player-side type, not because they're instructed not to use it.
- **Two-layer enforcement.** Layer 1 = data model (separate tables). Layer 2 = ViewModel discipline (`Player::*ViewModel` cannot return hidden attributes; `Narrator::*ViewModel` can).
- **Asymmetry test surface.** Every player-facing surface (ViewModel in Phase 5; prompt builder in Phase 8; rendered component in Phase 9) is asserted against `not_to_leak` style matchers. Phase 5 establishes the matcher and exercises it against ViewModels.
- **Campaign is the tenant root.** Every campaign-scoped table carries `campaign_id` with `on_delete: :cascade`. Phase 5 wires this for all four campaign-scoped tables (factions, npcs, scenes; events cascade transitively via scenes).
- **Single-user-per-campaign.** No `Membership`, no roles. Tenant scoping is achieved through `current_user.campaigns.find(params[:id])` at controller boundaries (introduced in Phase 6).
- **Default-deny auth on `ApplicationController`.** Phase 5 adds no controllers, so no auth changes.

### Why ViewModels at all

ViewModels are not generic MVVC ceremony. They are the structural enforcement mechanism for Phase 0's asymmetry-by-context-construction commitment.

If a player-facing component or prompt builder receives a `Faction` ActiveRecord instance, the entire model surface — `faction.secrets`, every column, every association — is reachable from that consumer. Asymmetry becomes a discipline ("don't write `.secrets` in player code") backed by code review and tests. That's exactly what Phase 0 motivation #2 rejects: v1's "narrator instructed not to read dm/" model.

A `Player::FactionViewModel` that defines only `:id, :name, :public_description` makes `view_model.secrets` raise `NoMethodError`. The leak is prevented by the method not existing, not by a rule. Any reviewer or static analyzer can verify, by reading the class definition alone, that the call graph from a player consumer cannot reach a FactionSecret row.

ViewModels are scoped to asymmetric models specifically. `Campaign` (Phase 3) and `User` have no hidden state and no player/narrator split; they don't need ViewModels and didn't get them. Phase 5 introduces the first asymmetric models (Faction, Npc) and therefore the first ViewModels. Future asymmetric models (Revelation, Module) will get ViewModels in their introducing phases.

## Open decisions resolved in this spec

### Event polymorphism: single table + `kind` enum + `payload` jsonb

**Decision:** one `events` table with a Rails enum `kind` (string column), a `payload` jsonb column, and an explicit `occurred_at` datetime. Per-kind reader/writer classes are deferred to Phase 6 when ViewComponents need to consume typed event data.

Alternatives considered:

- STI with a superset of typed columns — wide schema, every new kind is a migration, most columns are NULL on most rows.
- True polymorphic association to per-kind detail tables — six+ tables for events alone, joins on every scene-log render, heavy for small varied payloads.

The single-table approach is cheapest schema, easiest to add kinds, and the `payload` validation can move into per-kind Ruby classes in Phase 6 without a schema change.

### Event ordering: explicit `occurred_at`

**Decision:** `occurred_at` datetime column, indexed with `scene_id`. Defaults to `Time.current` on create but is settable so future kinds (e.g. backfilled or imported events) can declare a fictional timestamp distinct from `created_at`.

### Secrets cardinality: many-row, label + content

**Decision:** `faction_secrets` and `npc_secrets` are 1:N from their parent. Each row holds one named secret: `label` (string, ≤ 100) and `content` (text). `Faction has_many :secrets, class_name: "FactionSecret", dependent: :destroy`. Same for `Npc`.

Rationale: a cult faction realistically has multiple distinct hidden facts (true leader, hidden temple location, hidden funding source). A 1:1 columnar `FactionSecret` table forces every secret to be a named column, growing the schema with every new kind. The many-row model lets secrets be a collection from the start.

Phase 0's `faction_secrets` description ("hidden clock, hidden motivation, secret connections, etc.") was illustrative; Phase 0 commits to the *separation* of public and hidden state, not to a specific cardinality. Phase 0 also explicitly defers faction clocks to a post-MVP phase, so the schema does not need a `hidden_clock_segments` column at all.

No `kind` enum on secrets in Phase 5. No `revealed_at` column. No `target_*` polymorphic reference. All forward-looking and easy to add later when concrete callers exist.

### Faction name uniqueness: per `(campaign_id, lower(name))`

**Decision:** unique index on `(campaign_id, lower(name))` for factions, matching the existing `Campaign.name` uniqueness pattern (per-tenant, case-insensitive). Same model-level validation: `validates :name, uniqueness: { scope: :campaign_id, case_sensitive: false }`.

### Npc name uniqueness: none

**Decision:** no uniqueness on `npcs.name`. Two villagers named John in the same campaign is realistic; this matches play behavior, not a bug. NPC disambiguation in UI happens via `location` (Phase 6 concern).

### Scene ordering: `acts_as_list` scoped to campaign

**Decision:** add `acts_as_list` gem. Scene declares `acts_as_list scope: :campaign`. `position` integer column on scenes, indexed with `campaign_id`. Reordering is a callable operation from Phase 6 admin UI.

### ViewModel base: PORO + `expose` DSL

**Decision:** `app/view_models/application_view_model.rb` is a PORO base class with a class-level `expose` DSL that auto-defines reader methods and records the exposed attribute set on the class. `expose` accepts either a list of attribute names (sourced from the underlying record) or a single name with a block (for computed/traversed values, e.g. wrapping an associated collection in nested VMs).

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

    def exposed_attrs = (@exposed_attrs || []).dup.freeze

    private

    def record_exposed(attr)
      @exposed_attrs = (@exposed_attrs || []) + [attr]
    end
  end

  def initialize(record)
    @record = record
  end

  # Recursive render: nested VMs (anything responding to `to_h`) and
  # collections of them are unwrapped so leak_secrets_of can scan them.
  def to_h
    self.class.exposed_attrs.each_with_object({}) do |attr, h|
      h[attr] = render_value(public_send(attr))
    end
  end

  private

  def render_value(value)
    case value
    when ApplicationViewModel then value.to_h
    when Array                then value.map { render_value(_1) }
    else                           value
    end
  end
end
```

The block form is how narrator VMs surface associated secrets:

```ruby
expose :secrets do
  @record.secrets.map { Narrator::FactionSecretViewModel.new(_1) }
end
```

This records `:secrets` in `exposed_attrs`, makes `to_h` include the wrapped secret VMs (recursively rendered to hashes), and lets `leak_secrets_of` scan the secret content.

**Escape hatch.** When a specific ViewModel needs typed attribute coercion, validation, or form round-tripping, swap its base for `ActiveModel::Model` (with `ActiveModel::Attributes`) in that subclass. Document the moment it happens. Phase 5 does not need this for any of its four ViewModels.

### ViewModel directory layout

**Decision:** `app/view_models/{player,narrator}/`. `Player::` and `Narrator::` are pure namespaces in Phase 5 — no per-side base class. If a side-specific concern emerges later (e.g. narrator VMs always eager-load secrets, or player VMs always exclude `id`), promote to `Player::ApplicationViewModel` / `Narrator::ApplicationViewModel` at that point and migrate the existing two VMs per side.

### Matcher API: `leak_secrets_of` + `expose_attrs_via`

**Decision:** one unified matcher file at `spec/support/matchers/not_to_leak.rb` defining two RSpec matchers.

```ruby
# Dynamic content scan against a ViewModel or string.
expect(player_view_model).not_to leak_secrets_of(faction)
expect(rendered_prompt).not_to    leak_secrets_of(faction, npc)   # Phase 8+

# Structural assertion against a ViewModel class.
expect(Player::FactionViewModel).not_to expose_attrs_via(:secrets)
```

**`leak_secrets_of(*records)` behavior:**

1. For each record passed, collect every associated `*Secret` row's `label` and `content` strings. (Both — leaking a secret's label name "the hidden temple" is also a leak.)
2. Render the subject:
   - If the subject responds to `to_h`, deep-stringify the hash (the base `to_h` already recursively unwraps nested VMs and collections of VMs).
   - If the subject is a `String`, use it directly.
   - Other shapes (rendered ViewComponent objects) wire in via duck-typed `to_s` / `render_in` in later phases.
3. Assert no collected secret string is a substring of the rendered subject. Failure message names which secret leaked into which exposed attribute (or, for strings, which secret was found at what offset).

The matcher is symmetric: it succeeds when nothing leaks (Player VM case) and fails when secrets are present (Narrator VM case). Narrator VM specs use it positively (`expect(narrator_vm).to leak_secrets_of(faction)`) to document that the narrator VM is *supposed* to surface secrets.

**`expose_attrs_via(:assoc)` behavior:**

1. Receives a ViewModel class.
2. Checks whether `klass.exposed_attrs` contains the symbol `:assoc` — the heuristic being that exposing an association directly under its own name is the common leak shape.
3. Fails if `:assoc` is in `exposed_attrs`.

This catches the "exposed `:secrets` accidentally" case structurally — even when the fixture has no secrets (where `leak_secrets_of` would silently pass). It is a heuristic; a leak that disguises secrets behind a differently-named exposed attr (`expose :hidden_facts do; @record.secrets.map(&:content); end`) is not caught here but is caught by `leak_secrets_of` as soon as the fixture has secret content. The two matchers are complementary, not redundant.

### `acts_as_list` gem adoption

**Decision:** add `acts_as_list` to the Gemfile (default group). Scene uses it; no other Phase 5 model does. If future models (Revelation? Module section?) need ordering, they can adopt the same gem.

### No revelations / modules tables in Phase 5

**Decision:** Phase 0 names `revelations` / `revelation_secrets` and `modules` / `module_secrets`, but Phase 5's issue scope explicitly lists only Faction/Npc/Scene/Event. Revelations and modules are post-MVP per the Phase 0 roadmap; their tables and ViewModels land with those phases. The ViewModel and matcher infrastructure introduced in Phase 5 will apply to them unchanged.

### No `Pundit` / `CampaignScoped` concern in Phase 5

**Decision:** Phase 5 has no controllers, so no authorization or tenant-scoping primitives are needed yet. Phase 6 will introduce a `CampaignScoped` concern (or equivalent) when the first scene controller needs to scope by campaign.

## File inventory

Every file added in Phase 5, grouped by area. Canonical list for the implementation plan.

### Gemfile

Add to the default group:

```ruby
gem "acts_as_list"
```

`bundle install`. Commit `Gemfile.lock`.

### Migrations

Six migrations, run in dependency order.

`db/migrate/<ts>_create_factions.rb`:

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

`db/migrate/<ts>_create_faction_secrets.rb`:

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

`db/migrate/<ts>_create_npcs.rb`:

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

`db/migrate/<ts>_create_npc_secrets.rb`:

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

`db/migrate/<ts>_create_scenes.rb`:

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

`db/migrate/<ts>_create_events.rb`:

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

### Models

`app/models/faction.rb`:

```ruby
class Faction < ApplicationRecord
  belongs_to :campaign
  has_many :secrets, class_name: "FactionSecret", dependent: :destroy

  validates :name, presence: true,
                   length: { maximum: 100 },
                   uniqueness: { scope: :campaign_id, case_sensitive: false }
end
```

`app/models/faction_secret.rb`:

```ruby
class FactionSecret < ApplicationRecord
  belongs_to :faction

  validates :label,   presence: true, length: { maximum: 100 }
  validates :content, presence: true
end
```

`app/models/npc.rb`:

```ruby
class Npc < ApplicationRecord
  belongs_to :campaign
  has_many :secrets, class_name: "NpcSecret", dependent: :destroy

  validates :name, presence: true, length: { maximum: 100 }
end
```

`app/models/npc_secret.rb`:

```ruby
class NpcSecret < ApplicationRecord
  belongs_to :npc

  validates :label,   presence: true, length: { maximum: 100 }
  validates :content, presence: true
end
```

`app/models/scene.rb`:

```ruby
class Scene < ApplicationRecord
  belongs_to :campaign
  has_many :events, dependent: :destroy

  acts_as_list scope: :campaign

  validates :title, presence: true, length: { maximum: 100 }
end
```

`app/models/event.rb`:

```ruby
class Event < ApplicationRecord
  KINDS = %w[narration dice_roll oracle_query scene_transition].freeze

  belongs_to :scene

  enum :kind, KINDS.index_with(&:itself)

  validates :occurred_at, presence: true
  before_validation :default_occurred_at, on: :create

  private

  def default_occurred_at
    self.occurred_at ||= Time.current
  end
end
```

All six models receive `annotaterb` schema headers after migrations land.

### ViewModels

`app/view_models/application_view_model.rb` — base class with `expose` DSL (full body shown in §"ViewModel base").

`app/view_models/player/faction_view_model.rb`:

```ruby
module Player
  class FactionViewModel < ApplicationViewModel
    expose :id, :name, :public_description
  end
end
```

`app/view_models/player/npc_view_model.rb`:

```ruby
module Player
  class NpcViewModel < ApplicationViewModel
    expose :id, :name, :public_description, :location
  end
end
```

`app/view_models/narrator/faction_view_model.rb`:

```ruby
module Narrator
  class FactionViewModel < ApplicationViewModel
    expose :id, :name, :public_description

    expose :secrets do
      @record.secrets.map { Narrator::FactionSecretViewModel.new(_1) }
    end
  end
end
```

`app/view_models/narrator/faction_secret_view_model.rb`:

```ruby
module Narrator
  class FactionSecretViewModel < ApplicationViewModel
    expose :id, :label, :content
  end
end
```

`app/view_models/narrator/npc_view_model.rb` and `app/view_models/narrator/npc_secret_view_model.rb` — analogous to the faction pair.

Note: `Narrator::FactionViewModel` declares `:secrets` via the block form of `expose`. This records `:secrets` in `exposed_attrs` (so `to_h` includes it and `leak_secrets_of` can scan into the nested secret VMs) and structurally signals "this VM surfaces secrets" (so `expose_attrs_via(:secrets)` would match — by design — though that matcher is only asserted against player VMs).

### Test infrastructure

`spec/support/matchers/not_to_leak.rb` — defines `leak_secrets_of` and `expose_attrs_via` matchers with top-of-file docstring documenting usage, examples, and supported subject shapes.

`rails_helper` — verify the existing `spec/support/**/*.rb` autoload picks up the new `matchers/` subdirectory. (The existing glob in `rails_helper.rb` already does; no change expected, but the plan should sanity-check this.)

### Factories

Six new factory files under `spec/factories/`, each with annotaterb schema headers:

- `factories/factions.rb` — `campaign`, sequenced `name`, `public_description`. Trait `:with_secrets` creates two `FactionSecret` children.
- `factories/faction_secrets.rb` — `faction`, sequenced `label`, fixed `content`.
- `factories/npcs.rb` — `campaign`, sequenced `name`, `public_description`, `location`.
- `factories/npc_secrets.rb` — `npc`, sequenced `label`, fixed `content`.
- `factories/scenes.rb` — `campaign`, sequenced `title`. `position` auto-assigned by `acts_as_list`.
- `factories/events.rb` — `scene`, default `kind :narration`, default minimal `payload`. Traits `:dice_roll`, `:oracle_query`, `:scene_transition` set the matching kind and a representative minimal payload.

### Specs

**Model specs** (six total):

- `spec/models/faction_spec.rb` — validations, `has_many :secrets`, cascade from campaign (deletion test), per-`(campaign_id, lower(name))` uniqueness.
- `spec/models/faction_secret_spec.rb` — validations, `belongs_to :faction`, cascade on faction delete.
- `spec/models/npc_spec.rb` — validations, `has_many :secrets`, cascade from campaign, no name uniqueness (assert two Npcs named "John" coexist in one campaign).
- `spec/models/npc_secret_spec.rb` — validations, cascade.
- `spec/models/scene_spec.rb` — validations, `acts_as_list` ordering (`first?`, `last?`, `move_higher!`, position auto-assignment on create within a campaign scope), cascade from campaign.
- `spec/models/event_spec.rb` — `kind` enum mapping (each kind round-trips), unknown kind raises `ArgumentError`, `occurred_at` default-on-create, cascade from scene.

Cascade specs hit the real DB (no transactional fixtures workaround needed; the FK `on_delete: :cascade` is enforced by Postgres regardless of Rails' `dependent:`).

**ViewModel specs** (four total):

- `spec/view_models/player/faction_view_model_spec.rb`:
  - `exposed_attrs == [:id, :name, :public_description]`.
  - Returns model values for each exposed attr.
  - `expect(vm).not_to leak_secrets_of(faction)` against a faction with two secrets.
  - `expect(described_class).not_to expose_attrs_via(:secrets)` (structural).
- `spec/view_models/narrator/faction_view_model_spec.rb`:
  - `exposed_attrs` contains the public set.
  - `.secrets` returns `Narrator::FactionSecretViewModel` instances with `:label, :content` populated.
  - `expect(vm).to leak_secrets_of(faction)` — documents that the narrator VM is supposed to surface secrets.
- `spec/view_models/player/npc_view_model_spec.rb` — analogous to faction player spec.
- `spec/view_models/narrator/npc_view_model_spec.rb` — analogous to faction narrator spec.

**Matcher spec** (`spec/support/matchers/not_to_leak_spec.rb`):

- `leak_secrets_of` matches a string subject that contains a secret's `content`.
- `leak_secrets_of` matches a string subject that contains a secret's `label`.
- `leak_secrets_of` matches a ViewModel subject (via `to_h`) when an exposed attribute returns secret content.
- `leak_secrets_of` accepts multiple records: `leak_secrets_of(faction, npc)`.
- Failure message names the offending secret and the exposed attribute (assertion via `matcher.failure_message`).
- `expose_attrs_via(:secrets)` matches a class that has `:secrets` in `exposed_attrs` (e.g. the Narrator VM).
- `expose_attrs_via(:secrets)` does NOT match a class whose `exposed_attrs` excludes `:secrets` (e.g. the Player VM).
- Documented limitation: a class that exposes a differently-named attr which internally walks `@record.secrets` (e.g. `expose :hidden_facts do; @record.secrets.map(&:content); end`) is NOT matched by `expose_attrs_via(:secrets)`. One spec example documents this gap and demonstrates that `leak_secrets_of` catches it dynamically.

## Test surface summary

Phase 5 ends with:

- Six model specs covering validations, associations, cascade, and Scene ordering.
- Four ViewModel specs covering exposed-attr contracts and asymmetry assertions for Faction and Npc on both sides.
- One matcher spec covering both matchers and their failure messages.
- Six factory files supporting all of the above.

Total: ~11 spec files, ~6 factory files. No request specs, no system specs, no component specs (no UI yet).

## Non-goals for Phase 5

Explicit non-goals to prevent scope creep:

- No UI. No controllers. No routes. No views. No ViewComponents. No Lookbook previews.
- No `Scene` or `Event` ViewModels in Phase 5. These models have no `*_secrets` companion and no player/narrator asymmetric pair; their ViewModels (if any) are introduced when Phase 6 wires the play surface UI.
- No `Revelation` / `Module` tables. (Post-MVP, per Phase 0.)
- No faction clocks. (Post-MVP, per Phase 0.)
- No `revealed_at` column on secrets. Revelation mechanics land with the revelations phase.
- No per-kind Event reader/writer classes. `event.payload` is a raw Hash in Phase 5.
- No prompt builder. No LLM integration. (Phase 8.)
- No service objects writing Events. Events exist only via factories in Phase 5.
- No `Pundit` / `action_policy` / `CampaignScoped` concern. (First introduced when Phase 6 needs it.)
- No `pay` / `Stripe` / subscriptions. (Permanent v2-alpha non-goal per Phase 0.)
- No matcher integration with rendered ViewComponents. The matcher's subject duck-types on `to_h` and `String` only in Phase 5. Component subject support arrives in the phase that introduces components (Phase 6).

## Notes for the implementation plan

- The six migrations have inter-dependencies (secrets depend on parents, events on scenes). Generate them in dependency order so timestamps reflect order naturally.
- After migrations, run `bundle exec annotaterb models` to populate schema headers on the new model files.
- The `acts_as_list` gem is loaded application-wide via Gemfile; only Scene uses it in Phase 5.
- The matcher file (`spec/support/matchers/not_to_leak.rb`) is the load-bearing test infrastructure deliverable; allocate review time for it specifically.
- Phase 6 will consume `Player::FactionViewModel` and `Player::NpcViewModel` directly from ViewComponents and will likely add `Player::SceneViewModel` / `Player::EventViewModel` at that point (Scene and Event have no asymmetric pair in Phase 5 because they have no secret companion table — but Phase 6's UI will benefit from a Player VM for each anyway, for consistency with the ViewComponent base).
