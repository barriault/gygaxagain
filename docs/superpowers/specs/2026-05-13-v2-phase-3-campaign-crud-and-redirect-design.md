# v2 Phase 3 — User → Campaign + Campaign CRUD + auth redirect logic

Date: 2026-05-13
Status: Design spec. Drives the writing-plans pass for Phase 3.
Issue: [#4](https://github.com/barriault/gygaxagain/issues/4)
Parent roadmap: [`2026-05-13-v2-phase-0-roadmap-design.md`](2026-05-13-v2-phase-0-roadmap-design.md)
Prior phase: [`2026-05-13-v2-phase-2-devise-subdomain-admin-design.md`](2026-05-13-v2-phase-2-devise-subdomain-admin-design.md)

## Scope

Introduce the `Campaign` model and admin-side CRUD. The `User` table grows a `last_played_campaign_id` column. After-sign-in redirect lands the user according to one of three states: directly into the last-played campaign, the play-side picker if they have campaigns but no last-played, or the admin new-campaign form if they have none. A gated play-surface placeholder at `gygaxagain.com/campaigns/:id/play` 404s for non-owners. No associated tables yet (factions/NPCs/scenes land in Phase 5).

## Dependencies

Phase 2 (#3) complete: Devise + subdomain split + admin shell; default-deny auth on `ApplicationController`; cross-subdomain session sharing; manual user creation via `rake users:create`.

## Acceptance criteria

Verbatim from the GitHub issue:

- Admin user can create, edit, delete campaigns from `admin.gygaxagain.com/campaigns`.
- After sign-in, redirect logic places user correctly per the three cases (last-played / has-campaigns / no-campaigns).
- Play surface at `https://gygaxagain.com/campaigns/:id/play` is accessible only when `campaign.user_id == current_user.id`; 404 otherwise.
- Campaign deletion cascades cleanly to all associated rows.
- Tests cover the auth redirect matrix and the campaign ownership check.

(Note: "cascade cleanly to all associated rows" is forward-looking in Phase 3 — no tables reference `campaigns` yet. This spec sets the pattern by example: campaign-scoped tables added in Phase 5+ will declare `belongs_to :campaign` and the foreign key with `on_delete: :cascade`.)

## Architectural commitments inherited from Phase 0

Phase 0 already locks the multi-tenancy and asymmetry-model decisions. This spec applies them; it does not re-litigate them.

- **Single-user-per-campaign.** `User has_many :campaigns`; `Campaign belongs_to :user`. No `Membership` model, no roles, no sharing.
- **Tenant scoping via `current_user.campaigns.find(params[:id])`.** No `acts_as_tenant` gem. 404 (not 403) on cross-user access; we don't surface the existence of campaigns the user doesn't own.
- **Cascade scope.** Every campaign-scoped table (Phase 5+) carries `campaign_id` with `on_delete: :cascade`. Campaigns are the tenant root.
- **Pundit / `action_policy` still deferred.** Plain `current_user.campaigns` scoping is sufficient until rules grow non-trivial.
- **Default-deny auth on `ApplicationController`.** Phase 2 deviation stands: controllers default to authenticated; only `Play::HomeController` and `Users::SessionsController` skip. Phase 3 adds no new skips.

## Open decisions resolved in this spec

### `description` field on `Campaign`

**Decision:** keep a `description` text column on `campaigns`. Free-form notes from the campaign owner, distinct from any in-game text. The Phase 3 admin form has nothing else to render besides `name`; a notes field gives the form a second affordance, and the column is cheap to add. Optional, no validation beyond Rails defaults.

This is not the campaign's *premise* or *pitch* — it's a personal scratchpad for the campaign owner. Phase 5+ may introduce structured pitch/premise content; if so, this column can be repurposed or supplemented at that time.

### Per-user uniqueness of campaign name

**Decision:** unique index on `(user_id, name)` and a matching `validates :name, uniqueness: { scope: :user_id }`. Prevents the confusion of two campaigns named "Strahd" under the same account. Length capped at 100 characters (validation only; DB column is unbounded `string`).

### `last_played_campaign_id` FK behavior

**Decision:** FK with `on_delete: :nullify`. Deleting a campaign clears any user's pointer to it rather than leaving a dangling reference. The `after_sign_in_path_for` logic still includes a defensive `exists?` check (belt and suspenders against any test-only path or future code that bypasses the FK).

The reverse association (`Campaign has_many :users_for_whom_this_is_last_played`) is not modeled. There is only ever one user per campaign and the lookup direction is always `user → last_played_campaign`.

### Writing `last_played_campaign_id`

**Decision:** `Play::CampaignsController#play` writes `current_user.update_column(:last_played_campaign_id, campaign.id)` when the action runs.

- `update_column` (not `update!`) — bypasses validations and callbacks. Avoids touching `updated_at` / Devise trackable on every play action.
- The write is unconditional: every `#play` hit refreshes the pointer. This is correct semantically (last *visited* play surface = last *played*).
- Not yet wrapped in a service object; the one-liner stays inline until a second writer exists.

### Admin "show" action: omitted

**Decision:** `resources :campaigns, except: [:show]` in the admin namespace. There is no inner content for a campaign in Phase 3 — no factions, NPCs, scenes. The index row + edit form is the working "show". The action returns when Phase 5 adds associated rows worth surfacing.

### Play picker as a real index page

**Decision:** `gygaxagain.com/campaigns` is a real `Play::CampaignsController#index` rendering `Play::Campaigns::PickerComponent`. Reachable even when `last_played_campaign_id` is set; the after-sign-in redirect routes around it but the user can still navigate back.

### Ownership-404 vs ownership-403

**Decision:** 404 (`ActiveRecord::RecordNotFound` from `.find`) for cross-user access, not 403. We don't surface the existence of campaigns the user doesn't own. Rails' default `rescue_responses` translates this to a 404 in production.

This applies equally to the admin CRUD actions and the play surface. A user cannot determine whether a given `:id` exists.

### Strong params

**Decision:** `params.require(:campaign).permit(:name, :description)`. No tenant fields (`:user_id`) — those are inferred from `current_user`.

### Hotwire / Turbo confirmation on destroy

**Decision:** use `button_to "Delete", admin_campaign_path(campaign), method: :delete, data: { turbo_confirm: "Delete '#{campaign.name}'? This cannot be undone." }`. No separate confirmation page. Default Turbo confirm dialog is fine for solo alpha.

### Namespaced base controllers: still not introduced

**Decision:** `Admin::CampaignsController` inherits directly from `::ApplicationController`, matching the Phase 2 pattern for `Admin::DashboardController`. The Phase 2 spec's "Phase 0 deviations" section keeps namespaced bases out until they earn their keep; Phase 3 doesn't introduce any admin-wide before_actions, so the deviation stands.

If Phase 4+ adds an admin-wide concern (e.g., layout selection, before_action for ops timing), introduce `Admin::ApplicationController` at that point and migrate the existing two controllers in the same change.

## File inventory

Every file added or modified in Phase 3, grouped by area. Canonical list for the implementation plan.

### Migrations

Two migrations, run in order.

`db/migrate/<ts>_create_campaigns.rb`:

```ruby
class CreateCampaigns < ActiveRecord::Migration[8.1]
  def change
    create_table :campaigns do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.text :description
      t.timestamps
    end

    add_index :campaigns, [:user_id, :name], unique: true
  end
end
```

`db/migrate/<ts>_add_last_played_campaign_id_to_users.rb`:

```ruby
class AddLastPlayedCampaignIdToUsers < ActiveRecord::Migration[8.1]
  def change
    add_reference :users, :last_played_campaign,
                  foreign_key: { to_table: :campaigns, on_delete: :nullify },
                  null: true,
                  index: true
  end
end
```

`db/migrate/<ts>_add_last_played_campaign_id_to_users.rb` runs *after* `create_campaigns` so the FK target exists. Schema versioned by timestamp keeps ordering naturally.

### Models

`app/models/campaign.rb`:

```ruby
class Campaign < ApplicationRecord
  belongs_to :user

  validates :name, presence: true,
                   length: { maximum: 100 },
                   uniqueness: { scope: :user_id }
end
```

`app/models/user.rb` updated:

```ruby
class User < ApplicationRecord
  devise :database_authenticatable, :recoverable, :rememberable, :validatable,
         :trackable, :timeoutable, :lockable

  has_many :campaigns, dependent: :destroy
  belongs_to :last_played_campaign,
             class_name: "Campaign",
             optional: true
end
```

`annotaterb` runs against both models post-migration.

### Routes

`config/routes/admin.rb` updated. The existing `scope module: "admin"` is refactored to `scope module: "admin", as: :admin` so the helper-name prefix is handled by the scope, not per-route. Without this, `resources :campaigns` would generate `campaigns_path`, colliding with the play-side helper.

```ruby
constraints subdomain: "admin" do
  scope module: "admin", as: :admin do
    root "dashboard#show"
    get "/dashboard", to: "dashboard#show", as: :dashboard

    resources :campaigns, except: [:show]
  end
end
```

Resulting helpers: `admin_root_path`, `admin_dashboard_path`, `admin_campaigns_path`, `new_admin_campaign_path`, `edit_admin_campaign_path(id)`, `admin_campaign_path(id)`. The per-route `as: :admin_root` / `as: :admin_dashboard` from Phase 2 collapse into the scope's `as:`; the helper names themselves are unchanged.

`config/routes/play.rb` updated:

```ruby
constraints subdomain: "" do
  devise_for :users, skip: [:registrations], controllers: { sessions: "users/sessions" }

  root "play/home#show"

  scope module: "play" do
    resources :campaigns, only: [:index] do
      member { get :play }
    end
  end
end
```

This yields helpers `campaigns_path` (play index), `play_campaign_path(id)` (placeholder play surface), and the full admin CRUD set under `admin_*_campaign_path`.

### Controllers

`app/controllers/admin/campaigns_controller.rb` — new:

```ruby
module Admin
  class CampaignsController < ::ApplicationController
    before_action :load_campaign, only: [:edit, :update, :destroy]

    def index
      @campaigns = current_user.campaigns.order(:name)
      render Admin::Campaigns::IndexComponent.new(campaigns: @campaigns)
    end

    def new
      @campaign = current_user.campaigns.build
      render Admin::Campaigns::FormComponent.new(
        campaign: @campaign,
        form_url: admin_campaigns_path,
        method: :post
      )
    end

    def create
      @campaign = current_user.campaigns.build(campaign_params)
      if @campaign.save
        redirect_to admin_campaigns_path, notice: "Campaign created."
      else
        render Admin::Campaigns::FormComponent.new(
          campaign: @campaign,
          form_url: admin_campaigns_path,
          method: :post
        ), status: :unprocessable_entity
      end
    end

    def edit
      render Admin::Campaigns::FormComponent.new(
        campaign: @campaign,
        form_url: admin_campaign_path(@campaign),
        method: :patch
      )
    end

    def update
      if @campaign.update(campaign_params)
        redirect_to admin_campaigns_path, notice: "Campaign updated."
      else
        render Admin::Campaigns::FormComponent.new(
          campaign: @campaign,
          form_url: admin_campaign_path(@campaign),
          method: :patch
        ), status: :unprocessable_entity
      end
    end

    def destroy
      @campaign.destroy
      redirect_to admin_campaigns_path, notice: "Campaign deleted."
    end

    private

    def load_campaign
      @campaign = current_user.campaigns.find(params[:id])
    end

    def campaign_params
      params.require(:campaign).permit(:name, :description)
    end
  end
end
```

`app/controllers/play/campaigns_controller.rb` — new:

```ruby
module Play
  class CampaignsController < ::ApplicationController
    def index
      @campaigns = current_user.campaigns.order(:name)
      render Play::Campaigns::PickerComponent.new(campaigns: @campaigns)
    end

    def play
      @campaign = current_user.campaigns.find(params[:id])
      current_user.update_column(:last_played_campaign_id, @campaign.id)
      render Play::Campaigns::PlaceholderComponent.new(campaign: @campaign)
    end
  end
end
```

`app/controllers/application_controller.rb` — `after_sign_in_path_for` replaced:

```ruby
def after_sign_in_path_for(user)
  if user.last_played_campaign_id && user.campaigns.exists?(id: user.last_played_campaign_id)
    play_campaign_url(user.last_played_campaign_id, subdomain: "")
  elsif user.campaigns.any?
    campaigns_url(subdomain: "")
  else
    new_admin_campaign_url(subdomain: "admin")
  end
end
```

`after_sign_out_path_for` is unchanged from Phase 2.

### Components

Four new components, each with its template and a Lookbook preview.

- `app/components/admin/campaigns/index_component.rb` + `.html.erb` — table with name + created_at + edit/delete buttons + "New campaign" CTA. Empty-state message when `campaigns.empty?`.
- `app/components/admin/campaigns/form_component.rb` + `.html.erb` — shared new + edit form. Initializer takes `campaign:`, `form_url:`, `method:` (`:post` or `:patch`). Renders error summary when `campaign.errors.any?`.
- `app/components/play/campaigns/picker_component.rb` + `.html.erb` — list of campaigns, each linking to `play_campaign_path`. Sign-out link in footer. Note: empty-state is unreachable in practice (the redirect logic routes users with zero campaigns to admin); the component renders an empty `<ul>` if reached directly.
- `app/components/play/campaigns/placeholder_component.rb` + `.html.erb` — shows campaign name + "Play surface lands in Phase 6" + link back to picker. Initializer takes `campaign:`.

Lookbook previews mirror file paths: `spec/components/previews/admin/campaigns/index_component_preview.rb`, etc.

Styling stays consistent with the existing `Play::HomeComponent` and `Admin::DashboardComponent`: Tailwind dark theme (`bg-slate-900 text-slate-100`).

### Specs

Model specs:

- `spec/models/campaign_spec.rb` — validates name presence, uniqueness scoped to user, length ≤ 100; `belongs_to :user`.
- `spec/models/user_spec.rb` — `has_many :campaigns dependent: :destroy`; `belongs_to :last_played_campaign optional: true`; deleting a referenced campaign nulls `last_played_campaign_id` (FK-level test, exercises the migration).

Request specs:

- `spec/requests/admin/campaigns_spec.rb` — every CRUD action under three scenarios:
  - Unauthenticated → 302 to sign-in.
  - Owner → 200 / 302 (create+update+destroy redirect to index).
  - Other user's campaign on edit/update/destroy → 404.
  - `create` with invalid params → 422 (`unprocessable_entity`).
- `spec/requests/play/campaigns_spec.rb`:
  - `index` — unauth → 302; auth → 200, shows only `current_user.campaigns`.
  - `play` — unauth → 302; auth + owner → 200, `last_played_campaign_id` updated; auth + other user → 404.
- `spec/requests/after_sign_in_redirect_spec.rb` — the Phase 3 cornerstone. Four scenarios:
  - User with `last_played_campaign` (still owned) → `play_campaign_url`.
  - User with campaigns but `last_played_campaign_id` nil → `campaigns_url` (play picker).
  - User with zero campaigns → `new_admin_campaign_url` (admin form).
  - User with `last_played_campaign_id` set but the campaign was destroyed (the FK nullifies it, so this scenario also requires asserting the column was cleared) → behaves as the no-last-played case. Construct by deleting via `Campaign.destroy` rather than direct SQL, since the FK does the work.

System spec:

- `spec/system/campaign_authoring_spec.rb` — sign in → arrive on admin new-campaign form (no campaigns) → create one → see it on admin index → click edit → save changes → delete with confirmation → sign out → sign back in → land on admin new-campaign form again. Capybara `app_host` flips between `gygaxagain.com` and `admin.gygaxagain.com` across the redirect chain; the spec asserts on host as well as content at each step.

Component specs:

- `spec/components/admin/campaigns/index_component_spec.rb` — renders rows for given campaigns; renders empty-state when none.
- `spec/components/admin/campaigns/form_component_spec.rb` — renders name + description fields; renders error summary when campaign has errors; uses given form URL + method.
- `spec/components/play/campaigns/picker_component_spec.rb` — renders one link per campaign.
- `spec/components/play/campaigns/placeholder_component_spec.rb` — renders campaign name + "Phase 6" copy.

Factory:

- `spec/factories/campaigns.rb`:

```ruby
FactoryBot.define do
  factory :campaign do
    user
    sequence(:name) { |n| "Campaign #{n}" }
  end
end
```

### Lookbook previews

- `spec/components/previews/admin/campaigns/index_component_preview.rb` — two scenarios: with and without campaigns.
- `spec/components/previews/admin/campaigns/form_component_preview.rb` — three scenarios: new, edit, with-validation-errors.
- `spec/components/previews/play/campaigns/picker_component_preview.rb` — list of three campaigns.
- `spec/components/previews/play/campaigns/placeholder_component_preview.rb` — single placeholder.

## Implementation-level sequence

1. **Migrations.** Generate `CreateCampaigns` and `AddLastPlayedCampaignIdToUsers`. `bin/rails db:migrate`. Commit migrations + schema.rb.
2. **Models.** Add `app/models/campaign.rb`; update `app/models/user.rb` with the two new associations. Run `annotaterb`. Commit.
3. **Factory + model specs.** Add `spec/factories/campaigns.rb`, `spec/models/campaign_spec.rb`, and the new assertions in `spec/models/user_spec.rb`. `bundle exec rspec spec/models` clean. Commit.
4. **Admin routes + controller + components.** Add `admin/campaigns` to `config/routes/admin.rb`. Implement `Admin::CampaignsController` and the two admin components (index + form) with their previews. Commit.
5. **Admin request + component specs.** Cover the admin CRUD matrix and component rendering. `bundle exec rspec spec/requests/admin spec/components/admin` clean. Commit.
6. **Play routes + controller + components.** Add the play campaigns routes. Implement `Play::CampaignsController` (index + play) and the two play components (picker + placeholder) with their previews. Commit.
7. **Play request + component specs.** Cover the play index/play matrix and component rendering. `bundle exec rspec spec/requests/play spec/components/play` clean. Commit.
8. **After-sign-in redirect logic.** Replace `ApplicationController#after_sign_in_path_for`. Add `spec/requests/after_sign_in_redirect_spec.rb`. Commit.
9. **System spec.** Add `spec/system/campaign_authoring_spec.rb`. The Capybara host-flip pattern from Phase 2's `sign_in_spec.rb` extends naturally. Commit.
10. **Full RSpec + Brakeman + RuboCop + erb_lint.** Resolve any new offenses. Commit fixes as needed.
11. **README touch-up.** Add a brief "Campaigns" sub-section under Authentication describing the URL shape (`admin.gygaxagain.com/campaigns` for authoring, `gygaxagain.com/campaigns/:id/play` for play). Commit.
12. **Deploy.** Push to main / Heroku. Migrations run automatically via the release phase. Verify in production: create a campaign via admin; navigate to its play URL; sign out and back in to confirm the redirect lands on the play surface.

## Out of scope for Phase 3

Deferred to later phases (or until further notice):

- **Admin show page for a single campaign.** Returns when Phase 5 adds inner content (factions, NPCs).
- **Chaos factor or any other Mythic GME state.** Phase 7.
- **Associated tables.** Factions, NPCs, scenes, events — all Phase 5.
- **Real play surface UI.** Phase 6. The Phase 3 `play` action renders a placeholder.
- **Pundit / `action_policy`.** Plain `current_user.campaigns` scoping suffices.
- **Multi-user sharing.** Permanent out-of-scope per Phase 0.
- **Campaign archival / soft-delete.** Hard delete only; FK cascade handles cleanup.
- **Bulk campaign import.** Manual CRUD only.
- **Admin-side audit log of campaign edits.** Out of scope; `updated_at` is the only history.

## Self-review notes

- Acceptance criteria reverse-mapping:
  - "Admin user can create, edit, delete campaigns" → `spec/requests/admin/campaigns_spec.rb` + `spec/system/campaign_authoring_spec.rb`.
  - "After sign-in redirect places user correctly per the three cases" → `spec/requests/after_sign_in_redirect_spec.rb`.
  - "Play surface accessible only when `campaign.user_id == current_user.id`; 404 otherwise" → the `other user → 404` scenarios in `spec/requests/play/campaigns_spec.rb` and `spec/requests/admin/campaigns_spec.rb`.
  - "Campaign deletion cascades cleanly" → the FK assertion in `spec/models/user_spec.rb` (and forward-looking documentation in §"Architectural commitments"); no associated tables exist yet to exercise this further.
  - "Tests cover the auth redirect matrix and the campaign ownership check" → both spec files above.
- The `last_played_campaign_id` write happens in `Play::CampaignsController#play` via `update_column`. This means a user who never visits the play surface (only uses admin) never sets `last_played_campaign_id`, so the after-sign-in redirect lands them on the picker rather than directly on play. That is the correct behavior — "last played" means literally that.
- The picker is technically reachable in only two ways: explicit navigation to `/campaigns` while signed in, or the after-sign-in redirect when the user has campaigns but no last-played. The component handles its empty-state defensively (no campaigns) even though that state cannot be reached via the redirect flow.
- The four-case redirect matrix includes "stale `last_played_campaign_id`" even though the FK `on_delete: :nullify` should prevent this. The defensive `exists?` check + a spec asserting fall-through behavior is cheap insurance and documents the intent for future readers.
- No Phase 0 deviations introduced. The Phase 2 deviation (default-deny auth, no namespaced base controllers) carries forward without modification.
- The spec is intentionally repetitive of Phase 0 in places (multi-tenancy commitment, tenant scoping pattern) so a reader landing here directly understands the full picture without bouncing to Phase 0.
