# v2 Phase 3 — Campaign CRUD + auth redirect: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the `Campaign` model, admin CRUD at `admin.gygaxagain.com/campaigns`, the three-case after-sign-in redirect, and the 404-gated play surface placeholder at `gygaxagain.com/campaigns/:id/play`.

**Architecture:** Single-user-per-campaign with `User has_many :campaigns`. Tenant scoping via `current_user.campaigns.find(...)`. Routes split by subdomain (`config/routes/admin.rb` for admin, `config/routes/play.rb` for play). Default-deny auth on `ApplicationController` (inherited from Phase 2). Hotwire Turbo for confirm dialogs.

**Tech Stack:** Rails 8.1 · PostgreSQL · Devise · ViewComponent · Hotwire · RSpec · factory_bot · shoulda-matchers · Capybara (rack_test).

**Spec:** [`docs/superpowers/specs/2026-05-13-v2-phase-3-campaign-crud-and-redirect-design.md`](../specs/2026-05-13-v2-phase-3-campaign-crud-and-redirect-design.md).

**Spec deviation:** the spec mentions Lookbook previews for each new component. Phase 2 shipped without `spec/components/previews/` and the project has no preview file pattern yet. To match the project's actual state, this plan omits preview files. They can be added uniformly across all components in a small follow-up if/when Lookbook previews get adopted.

---

## File structure

**Models + migrations (Tasks 1–2):**
- `db/migrate/<ts>_create_campaigns.rb` — new
- `db/migrate/<ts>_add_last_played_campaign_id_to_users.rb` — new
- `app/models/campaign.rb` — new
- `app/models/user.rb` — modified (associations)
- `spec/factories/campaigns.rb` — new
- `spec/models/campaign_spec.rb` — new
- `spec/models/user_spec.rb` — modified (associations + cascade)

**Admin (Tasks 3–6):**
- `config/routes/admin.rb` — modified (scope refactor + `resources :campaigns`)
- `app/controllers/admin/campaigns_controller.rb` — new
- `app/components/admin/campaigns/index_component.rb` + `.html.erb` — new
- `app/components/admin/campaigns/form_component.rb` + `.html.erb` — new
- `spec/requests/admin/campaigns_spec.rb` — new (one file, exercised incrementally)
- `spec/components/admin/campaigns/index_component_spec.rb` — new
- `spec/components/admin/campaigns/form_component_spec.rb` — new

**Play (Tasks 7–8):**
- `config/routes/play.rb` — modified (scope + `resources :campaigns`)
- `app/controllers/play/campaigns_controller.rb` — new
- `app/components/play/campaigns/picker_component.rb` + `.html.erb` — new
- `app/components/play/campaigns/placeholder_component.rb` + `.html.erb` — new
- `spec/requests/play/campaigns_spec.rb` — new
- `spec/components/play/campaigns/picker_component_spec.rb` — new
- `spec/components/play/campaigns/placeholder_component_spec.rb` — new

**Redirect (Task 9):**
- `app/controllers/application_controller.rb` — modified (`after_sign_in_path_for`)
- `spec/requests/after_sign_in_redirect_spec.rb` — new

**System test + polish (Tasks 10–11):**
- `spec/system/campaign_authoring_spec.rb` — new
- `README.md` — modified (Campaigns sub-section)

---

## Task 1: Campaign model + migration + factory

**Files:**
- Create: `db/migrate/<ts>_create_campaigns.rb`
- Create: `app/models/campaign.rb`
- Create: `spec/factories/campaigns.rb`
- Create: `spec/models/campaign_spec.rb`

- [ ] **Step 1: Write the failing model spec**

Create `spec/models/campaign_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Campaign, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    subject { build(:campaign) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }

    it "validates uniqueness of name scoped to user" do
      user = create(:user)
      create(:campaign, user: user, name: "Strahd")
      duplicate = build(:campaign, user: user, name: "Strahd")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include("has already been taken")
    end

    it "allows two users to have campaigns with the same name" do
      user_a = create(:user)
      user_b = create(:user)
      create(:campaign, user: user_a, name: "Strahd")
      expect(build(:campaign, user: user_b, name: "Strahd")).to be_valid
    end
  end

  describe "factory" do
    it "creates a persistable campaign" do
      campaign = build(:campaign)
      expect(campaign).to be_valid
      expect { campaign.save! }.not_to raise_error
    end
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/models/campaign_spec.rb`
Expected: failure with `NameError: uninitialized constant Campaign` (or similar — model doesn't exist).

- [ ] **Step 3: Generate the migration**

Run: `bin/rails g migration CreateCampaigns user:references name:string description:text`

This generates a timestamped file like `db/migrate/20260513XXXXXX_create_campaigns.rb`. Open it.

- [ ] **Step 4: Edit the migration to final form**

Replace the generated body with:

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

- [ ] **Step 5: Run the migration**

Run: `bin/rails db:migrate`
Expected: `== CreateCampaigns: migrated` line in output, `db/schema.rb` updated.

Also run: `bin/rails db:migrate RAILS_ENV=test` (so the test DB has the new schema; `maintain_test_schema!` should pick it up automatically next test run, but running explicitly is safe).

- [ ] **Step 6: Create the Campaign model**

Create `app/models/campaign.rb`:

```ruby
class Campaign < ApplicationRecord
  belongs_to :user

  validates :name, presence: true,
                   length: { maximum: 100 },
                   uniqueness: { scope: :user_id }
end
```

- [ ] **Step 7: Create the factory**

Create `spec/factories/campaigns.rb`:

```ruby
FactoryBot.define do
  factory :campaign do
    user
    sequence(:name) { |n| "Campaign #{n}" }
  end
end
```

- [ ] **Step 8: Run the spec to verify it passes**

Run: `bundle exec rspec spec/models/campaign_spec.rb`
Expected: all examples pass.

- [ ] **Step 9: Annotate the model**

Run: `bundle exec annotaterb models`
Expected: `app/models/campaign.rb` gains a Schema Information comment header.

- [ ] **Step 10: Commit**

```bash
git add db/migrate/ db/schema.rb app/models/campaign.rb spec/factories/campaigns.rb spec/models/campaign_spec.rb
git commit -m "$(cat <<'EOF'
Add Campaign model + migration + factory (Phase 3.1)

belongs_to :user with on_delete: :cascade at the FK level.
Name presence + length(≤100) + uniqueness scoped to user.
Refs #4.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: User → Campaign association + last_played_campaign_id

**Files:**
- Create: `db/migrate/<ts>_add_last_played_campaign_id_to_users.rb`
- Modify: `app/models/user.rb`
- Modify: `spec/models/user_spec.rb`

- [ ] **Step 1: Add the failing association assertions**

Append to `spec/models/user_spec.rb` (inside the existing `RSpec.describe User, type: :model do` block, after the `describe "factory"` block):

```ruby
  describe "Campaign associations" do
    it { is_expected.to have_many(:campaigns).dependent(:destroy) }
    it { is_expected.to belong_to(:last_played_campaign).class_name("Campaign").optional }

    it "destroys child campaigns when the user is destroyed" do
      user = create(:user)
      create(:campaign, user: user)
      expect { user.destroy }.to change(Campaign, :count).by(-1)
    end

    it "nullifies last_played_campaign_id when the referenced campaign is destroyed" do
      user = create(:user)
      campaign = create(:campaign, user: user)
      user.update_column(:last_played_campaign_id, campaign.id)

      campaign.destroy
      user.reload
      expect(user.last_played_campaign_id).to be_nil
    end
  end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/models/user_spec.rb`
Expected: failures for missing `campaigns` and `last_played_campaign` associations.

- [ ] **Step 3: Generate the migration**

Run: `bin/rails g migration AddLastPlayedCampaignIdToUsers`

- [ ] **Step 4: Edit the migration**

Replace the generated body with:

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

- [ ] **Step 5: Run the migration**

Run: `bin/rails db:migrate`
Run: `bin/rails db:migrate RAILS_ENV=test`

- [ ] **Step 6: Update the User model**

Edit `app/models/user.rb` — add two associations under the existing `devise ...` line:

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

- [ ] **Step 7: Run the spec to verify it passes**

Run: `bundle exec rspec spec/models/user_spec.rb`
Expected: all examples pass (existing Devise tests + new Campaign tests).

- [ ] **Step 8: Re-annotate**

Run: `bundle exec annotaterb models`
Expected: `app/models/user.rb` annotation updated with `last_played_campaign_id` column and index. `app/models/campaign.rb` unchanged.

- [ ] **Step 9: Commit**

```bash
git add db/migrate/ db/schema.rb app/models/user.rb spec/models/user_spec.rb
git commit -m "$(cat <<'EOF'
Add User has_many :campaigns + last_played_campaign_id (Phase 3.2)

FK on_delete: :nullify so deleting a campaign clears the column
rather than dangling. Dependent: :destroy on the has_many ensures
deleting a user cleans up their campaigns. Refs #4.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Admin::CampaignsController#index + IndexComponent

**Files:**
- Modify: `config/routes/admin.rb`
- Create: `app/controllers/admin/campaigns_controller.rb`
- Create: `app/components/admin/campaigns/index_component.rb`
- Create: `app/components/admin/campaigns/index_component.html.erb`
- Create: `spec/requests/admin/campaigns_spec.rb`
- Create: `spec/components/admin/campaigns/index_component_spec.rb`

- [ ] **Step 1: Write the failing index request spec**

Create `spec/requests/admin/campaigns_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Admin::Campaigns", type: :request do
  before { host! "admin.gygaxagain.com" }

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe "GET /campaigns" do
    context "unauthenticated" do
      it "redirects to apex sign-in" do
        get "/campaigns"
        expect(response).to have_http_status(:found)
        expect(response.location).to include("gygaxagain.com/users/sign_in")
      end
    end

    context "authenticated" do
      before { sign_in user }

      it "renders the index with the user's campaigns" do
        own = create(:campaign, user: user, name: "Mine")
        create(:campaign, user: other_user, name: "Theirs")

        get "/campaigns"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Mine")
        expect(response.body).not_to include("Theirs")
      end

      it "renders an empty-state when the user has no campaigns" do
        get "/campaigns"
        expect(response).to have_http_status(:ok)
        expect(response.body).to match(/no campaigns/i)
      end
    end
  end
end
```

- [ ] **Step 2: Write the failing component spec**

Create `spec/components/admin/campaigns/index_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Admin::Campaigns::IndexComponent, type: :component do
  it "renders one row per campaign" do
    user = create(:user)
    campaigns = [create(:campaign, user: user, name: "Alpha"),
                 create(:campaign, user: user, name: "Beta")]
    render_inline(described_class.new(campaigns: campaigns))
    expect(page).to have_text("Alpha")
    expect(page).to have_text("Beta")
  end

  it "renders an empty-state when given an empty collection" do
    render_inline(described_class.new(campaigns: Campaign.none))
    expect(page).to have_text(/no campaigns/i)
  end

  it "renders a 'New campaign' CTA" do
    render_inline(described_class.new(campaigns: Campaign.none))
    expect(page).to have_link(/new campaign/i)
  end
end
```

- [ ] **Step 3: Run specs to verify they fail**

Run: `bundle exec rspec spec/requests/admin/campaigns_spec.rb spec/components/admin/campaigns/index_component_spec.rb`
Expected: failures — routes missing, component class missing.

- [ ] **Step 4: Refactor admin routes + add `resources :campaigns`**

Replace `config/routes/admin.rb` with:

```ruby
constraints subdomain: "admin" do
  scope module: "admin", as: :admin do
    root "dashboard#show"
    get "/dashboard", to: "dashboard#show", as: :dashboard

    resources :campaigns, except: [:show]
  end
end
```

Note: the existing `as: :admin_root` and `as: :admin_dashboard` collapse into the scope's `as:`; helper names (`admin_root_path`, `admin_dashboard_path`) are unchanged. New helpers from the resources: `admin_campaigns_path`, `new_admin_campaign_path`, `edit_admin_campaign_path(id)`, `admin_campaign_path(id)`.

- [ ] **Step 5: Create the controller**

Create `app/controllers/admin/campaigns_controller.rb`:

```ruby
module Admin
  class CampaignsController < ::ApplicationController
    def index
      @campaigns = current_user.campaigns.order(:name)
      render Admin::Campaigns::IndexComponent.new(campaigns: @campaigns)
    end
  end
end
```

(Remaining actions added in Tasks 4–6.)

- [ ] **Step 6: Create the component class**

Create `app/components/admin/campaigns/index_component.rb`:

```ruby
module Admin
  module Campaigns
    class IndexComponent < ViewComponent::Base
      def initialize(campaigns:)
        @campaigns = campaigns
      end

      attr_reader :campaigns
    end
  end
end
```

- [ ] **Step 7: Create the component template**

Create `app/components/admin/campaigns/index_component.html.erb`:

```erb
<div class="min-h-screen bg-slate-900 text-slate-100 px-4 py-12">
  <div class="mx-auto max-w-3xl">
    <div class="flex items-center justify-between">
      <h1 class="text-3xl font-bold tracking-tight">Campaigns</h1>
      <%= link_to "New campaign",
                  helpers.new_admin_campaign_path,
                  class: "text-sm uppercase tracking-widest text-slate-300 hover:text-slate-100" %>
    </div>

    <% if campaigns.any? %>
      <ul class="mt-8 divide-y divide-slate-800">
        <% campaigns.each do |campaign| %>
          <li class="py-4 flex items-center justify-between">
            <div>
              <p class="text-lg font-semibold"><%= campaign.name %></p>
              <p class="text-xs text-slate-500">
                Created <%= campaign.created_at.to_date.iso8601 %>
              </p>
            </div>
            <div class="flex items-center gap-4">
              <%= link_to "Edit",
                          helpers.edit_admin_campaign_path(campaign),
                          class: "text-sm text-slate-300 hover:text-slate-100" %>
              <%= button_to "Delete",
                            helpers.admin_campaign_path(campaign),
                            method: :delete,
                            data: { turbo_confirm: "Delete '#{campaign.name}'? This cannot be undone." },
                            class: "text-sm text-rose-400 hover:text-rose-200" %>
            </div>
          </li>
        <% end %>
      </ul>
    <% else %>
      <p class="mt-8 text-slate-400">No campaigns yet. Create one to start playing.</p>
    <% end %>

    <%= button_to "Sign out",
                  helpers.destroy_user_session_url(subdomain: ""),
                  method: :delete,
                  class: "mt-12 text-xs uppercase tracking-widest text-slate-500 hover:text-slate-300" %>
  </div>
</div>
```

- [ ] **Step 8: Run specs to verify they pass**

Run: `bundle exec rspec spec/requests/admin/campaigns_spec.rb spec/components/admin/campaigns/index_component_spec.rb`
Expected: all examples pass.

- [ ] **Step 9: Commit**

```bash
git add config/routes/admin.rb app/controllers/admin/campaigns_controller.rb app/components/admin/campaigns/ spec/requests/admin/campaigns_spec.rb spec/components/admin/campaigns/
git commit -m "$(cat <<'EOF'
Add Admin::Campaigns#index + IndexComponent (Phase 3.3)

Routes refactored to scope as: :admin so resources helpers get the
admin_ prefix without colliding with play-side campaigns_path. Index
lists current_user.campaigns ordered by name with empty-state and
New-campaign CTA. Refs #4.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Admin::CampaignsController#new + #create + FormComponent

**Files:**
- Modify: `app/controllers/admin/campaigns_controller.rb`
- Create: `app/components/admin/campaigns/form_component.rb`
- Create: `app/components/admin/campaigns/form_component.html.erb`
- Modify: `spec/requests/admin/campaigns_spec.rb`
- Create: `spec/components/admin/campaigns/form_component_spec.rb`

- [ ] **Step 1: Add failing new/create request specs**

Append to `spec/requests/admin/campaigns_spec.rb` inside the outer `RSpec.describe ...` block, after the `describe "GET /campaigns"` block:

```ruby
  describe "GET /campaigns/new" do
    context "unauthenticated" do
      it "redirects to apex sign-in" do
        get "/campaigns/new"
        expect(response).to have_http_status(:found)
        expect(response.location).to include("gygaxagain.com/users/sign_in")
      end
    end

    context "authenticated" do
      before { sign_in user }

      it "renders the form" do
        get "/campaigns/new"
        expect(response).to have_http_status(:ok)
        expect(response.body).to match(/name/i)
      end
    end
  end

  describe "POST /campaigns" do
    context "unauthenticated" do
      it "redirects to apex sign-in" do
        post "/campaigns", params: { campaign: { name: "X" } }
        expect(response).to have_http_status(:found)
        expect(response.location).to include("gygaxagain.com/users/sign_in")
      end
    end

    context "authenticated" do
      before { sign_in user }

      it "creates a campaign owned by the current user and redirects to the index" do
        expect {
          post "/campaigns", params: { campaign: { name: "Strahd", description: "Ravenloft" } }
        }.to change { user.campaigns.count }.by(1)

        expect(response).to have_http_status(:found)
        expect(response.location).to include("/campaigns")
        expect(user.campaigns.last.name).to eq("Strahd")
        expect(user.campaigns.last.description).to eq("Ravenloft")
      end

      it "rerenders the form with 422 on invalid input" do
        post "/campaigns", params: { campaign: { name: "" } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to match(/can.?t be blank|prohibited this/i)
      end
    end
  end
```

- [ ] **Step 2: Add failing form-component spec**

Create `spec/components/admin/campaigns/form_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Admin::Campaigns::FormComponent, type: :component do
  let(:user) { create(:user) }
  let(:new_campaign) { user.campaigns.build }

  it "renders name and description fields" do
    render_inline(described_class.new(
      campaign: new_campaign,
      form_url: "/campaigns",
      method: :post
    ))
    expect(page).to have_field("Name")
    expect(page).to have_field("Description")
  end

  it "renders a submit button" do
    render_inline(described_class.new(
      campaign: new_campaign,
      form_url: "/campaigns",
      method: :post
    ))
    expect(page).to have_button(/save|create|update/i)
  end

  it "renders an error summary when the campaign has errors" do
    invalid = user.campaigns.build(name: "")
    invalid.valid?

    render_inline(described_class.new(
      campaign: invalid,
      form_url: "/campaigns",
      method: :post
    ))
    expect(page).to have_text(/prohibited this campaign|errors prevented/i)
  end
end
```

- [ ] **Step 3: Run specs to verify they fail**

Run: `bundle exec rspec spec/requests/admin/campaigns_spec.rb spec/components/admin/campaigns/form_component_spec.rb`
Expected: failures — `Admin::Campaigns::FormComponent` missing, `new` / `create` actions missing.

- [ ] **Step 4: Extend the controller with new + create**

Replace `app/controllers/admin/campaigns_controller.rb` with:

```ruby
module Admin
  class CampaignsController < ::ApplicationController
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

    private

    def campaign_params
      params.require(:campaign).permit(:name, :description)
    end
  end
end
```

- [ ] **Step 5: Create the FormComponent class**

Create `app/components/admin/campaigns/form_component.rb`:

```ruby
module Admin
  module Campaigns
    class FormComponent < ViewComponent::Base
      def initialize(campaign:, form_url:, method:)
        @campaign = campaign
        @form_url = form_url
        @method = method
      end

      attr_reader :campaign, :form_url, :method
    end
  end
end
```

- [ ] **Step 6: Create the FormComponent template**

Create `app/components/admin/campaigns/form_component.html.erb`:

```erb
<div class="min-h-screen bg-slate-900 text-slate-100 px-4 py-12">
  <div class="mx-auto max-w-xl">
    <h1 class="text-3xl font-bold tracking-tight">
      <%= campaign.persisted? ? "Edit campaign" : "New campaign" %>
    </h1>

    <% if campaign.errors.any? %>
      <div class="mt-6 rounded border border-rose-700 bg-rose-950/40 px-4 py-3 text-sm text-rose-200">
        <p class="font-semibold">
          <%= pluralize(campaign.errors.count, "error") %> prohibited this campaign from being saved:
        </p>
        <ul class="mt-2 list-disc pl-5">
          <% campaign.errors.full_messages.each do |msg| %>
            <li><%= msg %></li>
          <% end %>
        </ul>
      </div>
    <% end %>

    <%= form_with model: campaign, url: form_url, method: method, local: true, class: "mt-8 space-y-6" do |f| %>
      <div>
        <%= f.label :name, class: "block text-sm uppercase tracking-widest text-slate-400" %>
        <%= f.text_field :name,
                         class: "mt-2 w-full rounded bg-slate-800 px-3 py-2 text-slate-100 focus:outline-none focus:ring-2 focus:ring-slate-500" %>
      </div>

      <div>
        <%= f.label :description, class: "block text-sm uppercase tracking-widest text-slate-400" %>
        <%= f.text_area :description,
                        rows: 6,
                        class: "mt-2 w-full rounded bg-slate-800 px-3 py-2 text-slate-100 focus:outline-none focus:ring-2 focus:ring-slate-500" %>
      </div>

      <div class="flex items-center gap-4">
        <%= f.submit (campaign.persisted? ? "Update campaign" : "Create campaign"),
                     class: "rounded bg-slate-100 px-4 py-2 text-sm font-semibold text-slate-900 hover:bg-white" %>
        <%= link_to "Cancel",
                    helpers.admin_campaigns_path,
                    class: "text-sm text-slate-400 hover:text-slate-200" %>
      </div>
    <% end %>
  </div>
</div>
```

- [ ] **Step 7: Run specs to verify they pass**

Run: `bundle exec rspec spec/requests/admin/campaigns_spec.rb spec/components/admin/campaigns/`
Expected: all examples pass (index from Task 3 still green, new/create from Task 4 now green, form component green).

- [ ] **Step 8: Commit**

```bash
git add app/controllers/admin/campaigns_controller.rb app/components/admin/campaigns/form_component* spec/requests/admin/campaigns_spec.rb spec/components/admin/campaigns/form_component_spec.rb
git commit -m "$(cat <<'EOF'
Add Admin::Campaigns#new + #create + FormComponent (Phase 3.4)

FormComponent shared between new/create and edit/update (Task 3.5).
422 on invalid input rerenders the form with error summary.
Refs #4.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Admin::CampaignsController#edit + #update

**Files:**
- Modify: `app/controllers/admin/campaigns_controller.rb`
- Modify: `spec/requests/admin/campaigns_spec.rb`

- [ ] **Step 1: Add failing edit/update specs**

Append to `spec/requests/admin/campaigns_spec.rb` inside the outer describe block:

```ruby
  describe "GET /campaigns/:id/edit" do
    context "unauthenticated" do
      it "redirects to apex sign-in" do
        campaign = create(:campaign, user: user)
        get "/campaigns/#{campaign.id}/edit"
        expect(response).to have_http_status(:found)
        expect(response.location).to include("gygaxagain.com/users/sign_in")
      end
    end

    context "authenticated as owner" do
      before { sign_in user }

      it "renders the edit form" do
        campaign = create(:campaign, user: user, name: "Strahd")
        get "/campaigns/#{campaign.id}/edit"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Strahd")
      end
    end

    context "authenticated as another user" do
      before { sign_in user }

      it "404s on another user's campaign" do
        foreign = create(:campaign, user: other_user)
        get "/campaigns/#{foreign.id}/edit"
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH /campaigns/:id" do
    context "authenticated as owner" do
      before { sign_in user }

      it "updates the campaign and redirects to the index" do
        campaign = create(:campaign, user: user, name: "Old")
        patch "/campaigns/#{campaign.id}", params: { campaign: { name: "New" } }

        expect(response).to have_http_status(:found)
        expect(response.location).to include("/campaigns")
        expect(campaign.reload.name).to eq("New")
      end

      it "rerenders the form with 422 on invalid input" do
        campaign = create(:campaign, user: user, name: "Keep")
        patch "/campaigns/#{campaign.id}", params: { campaign: { name: "" } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(campaign.reload.name).to eq("Keep")
      end
    end

    context "authenticated as another user" do
      before { sign_in user }

      it "404s on another user's campaign" do
        foreign = create(:campaign, user: other_user, name: "Theirs")
        patch "/campaigns/#{foreign.id}", params: { campaign: { name: "Hijacked" } }
        expect(response).to have_http_status(:not_found)
        expect(foreign.reload.name).to eq("Theirs")
      end
    end
  end
```

- [ ] **Step 2: Run specs to verify they fail**

Run: `bundle exec rspec spec/requests/admin/campaigns_spec.rb`
Expected: failures on the new edit/update examples (actions missing).

- [ ] **Step 3: Extend the controller with edit + update**

Replace `app/controllers/admin/campaigns_controller.rb` with:

```ruby
module Admin
  class CampaignsController < ::ApplicationController
    before_action :load_campaign, only: [:edit, :update]

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

- [ ] **Step 4: Run specs to verify they pass**

Run: `bundle exec rspec spec/requests/admin/campaigns_spec.rb`
Expected: all examples pass.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/admin/campaigns_controller.rb spec/requests/admin/campaigns_spec.rb
git commit -m "$(cat <<'EOF'
Add Admin::Campaigns#edit + #update (Phase 3.5)

Cross-user access returns 404 via current_user.campaigns.find raising
RecordNotFound. Refs #4.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Admin::CampaignsController#destroy

**Files:**
- Modify: `app/controllers/admin/campaigns_controller.rb`
- Modify: `spec/requests/admin/campaigns_spec.rb`

- [ ] **Step 1: Add failing destroy specs**

Append to `spec/requests/admin/campaigns_spec.rb` inside the outer describe block:

```ruby
  describe "DELETE /campaigns/:id" do
    context "unauthenticated" do
      it "redirects to apex sign-in" do
        campaign = create(:campaign, user: user)
        delete "/campaigns/#{campaign.id}"
        expect(response).to have_http_status(:found)
        expect(response.location).to include("gygaxagain.com/users/sign_in")
      end
    end

    context "authenticated as owner" do
      before { sign_in user }

      it "deletes the campaign and redirects to the index" do
        campaign = create(:campaign, user: user)
        expect { delete "/campaigns/#{campaign.id}" }
          .to change { user.campaigns.count }.by(-1)
        expect(response).to have_http_status(:found)
        expect(response.location).to include("/campaigns")
      end

      it "nullifies last_played_campaign_id when deleting the last-played campaign" do
        campaign = create(:campaign, user: user)
        user.update_column(:last_played_campaign_id, campaign.id)

        delete "/campaigns/#{campaign.id}"

        user.reload
        expect(user.last_played_campaign_id).to be_nil
      end
    end

    context "authenticated as another user" do
      before { sign_in user }

      it "404s on another user's campaign and does not delete it" do
        foreign = create(:campaign, user: other_user)
        expect { delete "/campaigns/#{foreign.id}" }
          .not_to change(Campaign, :count)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
```

- [ ] **Step 2: Run specs to verify they fail**

Run: `bundle exec rspec spec/requests/admin/campaigns_spec.rb`
Expected: failures on destroy examples (action missing).

- [ ] **Step 3: Add destroy action to controller**

In `app/controllers/admin/campaigns_controller.rb`, add `:destroy` to the `before_action :load_campaign` list, and add the destroy action.

Change the `before_action` line from:
```ruby
    before_action :load_campaign, only: [:edit, :update]
```
to:
```ruby
    before_action :load_campaign, only: [:edit, :update, :destroy]
```

And add a `destroy` action, after `update`:

```ruby
    def destroy
      @campaign.destroy
      redirect_to admin_campaigns_path, notice: "Campaign deleted."
    end
```

- [ ] **Step 4: Run specs to verify they pass**

Run: `bundle exec rspec spec/requests/admin/campaigns_spec.rb`
Expected: all examples pass.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/admin/campaigns_controller.rb spec/requests/admin/campaigns_spec.rb
git commit -m "$(cat <<'EOF'
Add Admin::Campaigns#destroy (Phase 3.6)

FK on_delete: :nullify clears users.last_played_campaign_id pointing
at the deleted campaign — verified in spec. Refs #4.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Play::CampaignsController#index + PickerComponent

**Files:**
- Modify: `config/routes/play.rb`
- Create: `app/controllers/play/campaigns_controller.rb`
- Create: `app/components/play/campaigns/picker_component.rb`
- Create: `app/components/play/campaigns/picker_component.html.erb`
- Create: `spec/requests/play/campaigns_spec.rb`
- Create: `spec/components/play/campaigns/picker_component_spec.rb`

- [ ] **Step 1: Write the failing request spec**

Create `spec/requests/play/campaigns_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Play::Campaigns", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe "GET /campaigns" do
    context "unauthenticated" do
      it "redirects to sign-in" do
        get "/campaigns"
        expect(response).to have_http_status(:found)
        expect(response.location).to include("/users/sign_in")
      end
    end

    context "authenticated" do
      before { sign_in user }

      it "renders the picker with the user's campaigns" do
        create(:campaign, user: user, name: "Mine")
        create(:campaign, user: other_user, name: "Theirs")

        get "/campaigns"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Mine")
        expect(response.body).not_to include("Theirs")
      end
    end
  end
end
```

- [ ] **Step 2: Write the failing component spec**

Create `spec/components/play/campaigns/picker_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Play::Campaigns::PickerComponent, type: :component do
  it "renders one link per campaign" do
    user = create(:user)
    campaigns = [create(:campaign, user: user, name: "Alpha"),
                 create(:campaign, user: user, name: "Beta")]

    render_inline(described_class.new(campaigns: campaigns))

    expect(page).to have_link("Alpha")
    expect(page).to have_link("Beta")
  end

  it "renders an empty-state when given an empty collection" do
    render_inline(described_class.new(campaigns: Campaign.none))
    expect(page).to have_text(/no campaigns/i)
  end
end
```

- [ ] **Step 3: Run specs to verify they fail**

Run: `bundle exec rspec spec/requests/play/campaigns_spec.rb spec/components/play/campaigns/picker_component_spec.rb`
Expected: route + component class missing.

- [ ] **Step 4: Update play routes**

Replace `config/routes/play.rb` with:

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

Resulting helpers: `campaigns_path` → `Play::CampaignsController#index`, `play_campaign_path(id)` → `Play::CampaignsController#play`.

- [ ] **Step 5: Create the controller**

Create `app/controllers/play/campaigns_controller.rb`:

```ruby
module Play
  class CampaignsController < ::ApplicationController
    def index
      @campaigns = current_user.campaigns.order(:name)
      render Play::Campaigns::PickerComponent.new(campaigns: @campaigns)
    end
  end
end
```

(The `play` action is added in Task 8.)

- [ ] **Step 6: Create the component class**

Create `app/components/play/campaigns/picker_component.rb`:

```ruby
module Play
  module Campaigns
    class PickerComponent < ViewComponent::Base
      def initialize(campaigns:)
        @campaigns = campaigns
      end

      attr_reader :campaigns
    end
  end
end
```

- [ ] **Step 7: Create the component template**

Create `app/components/play/campaigns/picker_component.html.erb`:

```erb
<div class="min-h-screen bg-slate-900 text-slate-100 px-4 py-12">
  <div class="mx-auto max-w-xl">
    <h1 class="text-3xl font-bold tracking-tight">Choose a campaign</h1>

    <% if campaigns.any? %>
      <ul class="mt-8 space-y-3">
        <% campaigns.each do |campaign| %>
          <li>
            <%= link_to campaign.name,
                        helpers.play_campaign_path(campaign),
                        class: "block rounded bg-slate-800 px-4 py-3 text-lg hover:bg-slate-700" %>
          </li>
        <% end %>
      </ul>
    <% else %>
      <p class="mt-8 text-slate-400">No campaigns yet.</p>
    <% end %>

    <%= button_to "Sign out",
                  helpers.destroy_user_session_url(subdomain: ""),
                  method: :delete,
                  class: "mt-12 text-xs uppercase tracking-widest text-slate-500 hover:text-slate-300" %>
  </div>
</div>
```

- [ ] **Step 8: Run specs to verify they pass**

Run: `bundle exec rspec spec/requests/play/campaigns_spec.rb spec/components/play/campaigns/picker_component_spec.rb`
Expected: all examples pass.

- [ ] **Step 9: Commit**

```bash
git add config/routes/play.rb app/controllers/play/campaigns_controller.rb app/components/play/campaigns/picker_component* spec/requests/play/campaigns_spec.rb spec/components/play/campaigns/picker_component_spec.rb
git commit -m "$(cat <<'EOF'
Add Play::Campaigns#index + PickerComponent (Phase 3.7)

Picker is reachable at gygaxagain.com/campaigns even when the user has
a last_played_campaign; the after-sign-in redirect (Task 3.9) routes
around it for that case but lets the user navigate back. Refs #4.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Play::CampaignsController#play + PlaceholderComponent

**Files:**
- Modify: `app/controllers/play/campaigns_controller.rb`
- Create: `app/components/play/campaigns/placeholder_component.rb`
- Create: `app/components/play/campaigns/placeholder_component.html.erb`
- Modify: `spec/requests/play/campaigns_spec.rb`
- Create: `spec/components/play/campaigns/placeholder_component_spec.rb`

- [ ] **Step 1: Add failing request specs for #play**

Append to `spec/requests/play/campaigns_spec.rb` inside the outer describe block:

```ruby
  describe "GET /campaigns/:id/play" do
    context "unauthenticated" do
      it "redirects to sign-in" do
        campaign = create(:campaign, user: user)
        get "/campaigns/#{campaign.id}/play"
        expect(response).to have_http_status(:found)
        expect(response.location).to include("/users/sign_in")
      end
    end

    context "authenticated as owner" do
      before { sign_in user }

      it "renders the placeholder" do
        campaign = create(:campaign, user: user, name: "Strahd")
        get "/campaigns/#{campaign.id}/play"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Strahd")
        expect(response.body).to match(/phase 6|coming/i)
      end

      it "updates last_played_campaign_id" do
        campaign = create(:campaign, user: user)
        get "/campaigns/#{campaign.id}/play"
        user.reload
        expect(user.last_played_campaign_id).to eq(campaign.id)
      end
    end

    context "authenticated as another user" do
      before { sign_in user }

      it "404s on another user's campaign and does not touch last_played" do
        foreign = create(:campaign, user: other_user)
        user.update_column(:last_played_campaign_id, nil)

        get "/campaigns/#{foreign.id}/play"
        expect(response).to have_http_status(:not_found)

        user.reload
        expect(user.last_played_campaign_id).to be_nil
      end
    end
  end
```

- [ ] **Step 2: Write the failing placeholder-component spec**

Create `spec/components/play/campaigns/placeholder_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Play::Campaigns::PlaceholderComponent, type: :component do
  it "renders the campaign name and a 'Phase 6' copy" do
    user = create(:user)
    campaign = create(:campaign, user: user, name: "Strahd")

    render_inline(described_class.new(campaign: campaign))

    expect(page).to have_text("Strahd")
    expect(page).to have_text(/phase 6|coming/i)
  end
end
```

- [ ] **Step 3: Run specs to verify they fail**

Run: `bundle exec rspec spec/requests/play/campaigns_spec.rb spec/components/play/campaigns/placeholder_component_spec.rb`
Expected: failures — `play` action and placeholder component missing.

- [ ] **Step 4: Extend the play controller**

Replace `app/controllers/play/campaigns_controller.rb` with:

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

- [ ] **Step 5: Create the placeholder component class**

Create `app/components/play/campaigns/placeholder_component.rb`:

```ruby
module Play
  module Campaigns
    class PlaceholderComponent < ViewComponent::Base
      def initialize(campaign:)
        @campaign = campaign
      end

      attr_reader :campaign
    end
  end
end
```

- [ ] **Step 6: Create the placeholder template**

Create `app/components/play/campaigns/placeholder_component.html.erb`:

```erb
<div class="min-h-screen bg-slate-900 text-slate-100 px-4 py-12">
  <div class="mx-auto max-w-xl">
    <p class="text-xs uppercase tracking-widest text-slate-500">Now playing</p>
    <h1 class="mt-2 text-3xl font-bold tracking-tight"><%= campaign.name %></h1>

    <p class="mt-8 text-slate-300">
      The real play surface lands in Phase 6. This is a placeholder so the
      after-sign-in redirect has somewhere to go.
    </p>

    <div class="mt-12 flex items-center gap-4">
      <%= link_to "Back to campaigns",
                  helpers.campaigns_path,
                  class: "text-sm text-slate-300 hover:text-slate-100" %>
      <%= button_to "Sign out",
                    helpers.destroy_user_session_url(subdomain: ""),
                    method: :delete,
                    class: "text-xs uppercase tracking-widest text-slate-500 hover:text-slate-300" %>
    </div>
  </div>
</div>
```

- [ ] **Step 7: Run specs to verify they pass**

Run: `bundle exec rspec spec/requests/play/campaigns_spec.rb spec/components/play/campaigns/`
Expected: all examples pass.

- [ ] **Step 8: Commit**

```bash
git add app/controllers/play/campaigns_controller.rb app/components/play/campaigns/placeholder_component* spec/requests/play/campaigns_spec.rb spec/components/play/campaigns/placeholder_component_spec.rb
git commit -m "$(cat <<'EOF'
Add Play::Campaigns#play + PlaceholderComponent (Phase 3.8)

#play sets last_played_campaign_id via update_column (bypasses
validations + Devise trackable). Cross-user access 404s. Refs #4.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: After-sign-in three-case redirect

**Files:**
- Modify: `app/controllers/application_controller.rb`
- Create: `spec/requests/after_sign_in_redirect_spec.rb`

- [ ] **Step 1: Write the failing redirect spec**

Create `spec/requests/after_sign_in_redirect_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "After sign-in redirect", type: :request do
  let(:password) { "correct horse battery staple" }
  let(:user) { create(:user, password: password, password_confirmation: password) }

  def sign_in_with(user)
    post "/users/sign_in",
         params: { user: { email: user.email, password: password } }
  end

  context "when the user has a last_played_campaign (still owned)" do
    it "redirects to play_campaign_url on apex" do
      campaign = create(:campaign, user: user)
      user.update_column(:last_played_campaign_id, campaign.id)

      sign_in_with(user)

      expect(response).to have_http_status(:found)
      expect(response.location).to include("gygaxagain.com/campaigns/#{campaign.id}/play")
    end
  end

  context "when the user has campaigns but no last_played" do
    it "redirects to the play picker (campaigns_url on apex)" do
      create(:campaign, user: user)

      sign_in_with(user)

      expect(response).to have_http_status(:found)
      expect(response.location).to match(%r{gygaxagain\.com/campaigns(?!/)})
    end
  end

  context "when the user has zero campaigns" do
    it "redirects to new_admin_campaign_url" do
      sign_in_with(user)

      expect(response).to have_http_status(:found)
      expect(response.location).to include("admin.gygaxagain.com/campaigns/new")
    end
  end

  context "when last_played_campaign_id is stale (campaign deleted)" do
    it "falls through to the next case" do
      campaign = create(:campaign, user: user)
      user.update_column(:last_played_campaign_id, campaign.id)
      campaign.destroy  # FK nullify should clear the column

      sign_in_with(user)

      # User now has zero campaigns, so falls through to new_admin_campaign_url
      expect(response).to have_http_status(:found)
      expect(response.location).to include("admin.gygaxagain.com/campaigns/new")
    end
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/requests/after_sign_in_redirect_spec.rb`
Expected: all four examples fail — current `after_sign_in_path_for` always returns `admin_dashboard_url`.

- [ ] **Step 3: Replace `after_sign_in_path_for`**

Edit `app/controllers/application_controller.rb`. Replace the `after_sign_in_path_for` method body with:

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

The full updated `ApplicationController` should look like:

```ruby
class ApplicationController < ActionController::Base
  # Default-deny: every controller authenticates unless it explicitly skips.
  # Public surfaces use `skip_before_action :authenticate_user!`.
  before_action :authenticate_user!

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  protected

  def after_sign_in_path_for(user)
    if user.last_played_campaign_id && user.campaigns.exists?(id: user.last_played_campaign_id)
      play_campaign_url(user.last_played_campaign_id, subdomain: "")
    elsif user.campaigns.any?
      campaigns_url(subdomain: "")
    else
      new_admin_campaign_url(subdomain: "admin")
    end
  end

  def after_sign_out_path_for(_resource_or_scope)
    root_url(subdomain: "")
  end
end
```

- [ ] **Step 4: Run the spec to verify it passes**

Run: `bundle exec rspec spec/requests/after_sign_in_redirect_spec.rb`
Expected: all four examples pass.

- [ ] **Step 5: Run the existing sign-in spec to confirm it still passes**

The existing `spec/system/sign_in_spec.rb` asserts post-sign-in lands on the admin dashboard. With Task 9's change, a user with zero campaigns lands on `admin.gygaxagain.com/campaigns/new` (admin new-campaign form), not the dashboard. The existing assertion (`expect(page).to have_text(/admin dashboard/i)`) will fail.

Update the assertion to reflect the new behavior. Edit `spec/system/sign_in_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Sign in", type: :system do
  before do
    driven_by :rack_test
    Capybara.app_host = "http://gygaxagain.com"
  end

  let(:password) { "correct horse battery staple" }
  let!(:user) { create(:user, password: password, password_confirmation: password) }

  it "signs in via the apex form and lands on the admin new-campaign form (no campaigns)" do
    visit "/users/sign_in"
    expect(page).to have_field("Email")
    expect(page).to have_field("Password")

    fill_in "Email", with: user.email
    fill_in "Password", with: password
    click_button "Log in"

    # User has zero campaigns → after_sign_in_path_for sends them to the admin new-campaign form.
    expect(current_url).to include("admin.gygaxagain.com/campaigns/new")
    expect(page).to have_text(/new campaign/i)
  end
end
```

- [ ] **Step 6: Run the full sign-in journey suite**

Run: `bundle exec rspec spec/system/sign_in_spec.rb spec/requests/after_sign_in_redirect_spec.rb spec/requests/devise_routes_spec.rb spec/requests/cross_subdomain_session_spec.rb`
Expected: all examples pass.

- [ ] **Step 7: Commit**

```bash
git add app/controllers/application_controller.rb spec/requests/after_sign_in_redirect_spec.rb spec/system/sign_in_spec.rb
git commit -m "$(cat <<'EOF'
Add three-case after-sign-in redirect (Phase 3.9)

last-played → /campaigns/:id/play on apex.
has-campaigns no-last-played → /campaigns picker on apex.
no campaigns → /campaigns/new on admin.

Defensive exists? check guards stale last_played_campaign_id even
though the FK nullifies it on campaign destroy. Existing sign-in
system spec updated to assert the new no-campaigns destination
(admin new-campaign form, not the empty dashboard). Refs #4.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: End-to-end campaign authoring system spec

**Files:**
- Create: `spec/system/campaign_authoring_spec.rb`

- [ ] **Step 1: Write the system spec**

Create `spec/system/campaign_authoring_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Campaign authoring (end-to-end)", type: :system do
  before { driven_by :rack_test }

  let(:password) { "correct horse battery staple" }
  let!(:user) { create(:user, password: password, password_confirmation: password) }

  it "lets a user sign in, create, edit, and delete a campaign, then signs out" do
    # Sign in on apex.
    Capybara.app_host = "http://gygaxagain.com"
    visit "/users/sign_in"
    fill_in "Email", with: user.email
    fill_in "Password", with: password
    click_button "Log in"

    # Zero campaigns → landed on admin new-campaign form.
    expect(current_url).to include("admin.gygaxagain.com/campaigns/new")
    expect(page).to have_text(/new campaign/i)

    # Create a campaign.
    fill_in "Name", with: "Curse of Strahd"
    fill_in "Description", with: "Ravenloft, gothic horror."
    click_button "Create campaign"

    # Redirected to the admin index, sees the new campaign.
    expect(current_url).to include("admin.gygaxagain.com/campaigns")
    expect(page).to have_text("Curse of Strahd")

    # Edit it.
    click_link "Edit"
    expect(current_url).to match(%r{admin\.gygaxagain\.com/campaigns/\d+/edit})
    fill_in "Name", with: "Curse of Strahd: Revised"
    click_button "Update campaign"

    expect(current_url).to include("admin.gygaxagain.com/campaigns")
    expect(page).to have_text("Curse of Strahd: Revised")

    # Delete it. Turbo confirm isn't simulated under rack_test; the button_to
    # POSTs the delete directly.
    click_button "Delete"
    expect(current_url).to include("admin.gygaxagain.com/campaigns")
    expect(page).to have_text(/no campaigns yet/i)

    # Sign out from admin → lands on apex root.
    click_button "Sign out"
    expect(current_url).to eq("http://gygaxagain.com/")
  end
end
```

- [ ] **Step 2: Run the spec to verify it passes**

Run: `bundle exec rspec spec/system/campaign_authoring_spec.rb`
Expected: all examples pass. If a step fails (e.g., button label mismatch), reconcile against the actual rendered HTML; the spec is the documentation of the flow.

- [ ] **Step 3: Commit**

```bash
git add spec/system/campaign_authoring_spec.rb
git commit -m "$(cat <<'EOF'
Add end-to-end campaign authoring system spec (Phase 3.10)

Covers sign-in (no-campaigns redirect) → create → admin index →
edit → delete → sign-out flow. rack_test driver does not simulate
the Turbo confirm dialog; the button_to POSTs the delete directly,
which is sufficient for the request-flow coverage. Refs #4.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: README touch-up + full lint pass

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Run the full test + lint suite**

Run each command and address any offenses:

```bash
bundle exec rspec
bin/rubocop
bin/brakeman
bundle exec erb_lint --lint-all
```

Expected: all green. If RuboCop flags anything (most likely whitespace or string-literal style in the new files), run `bin/rubocop -a` to auto-correct, then re-run the full RuboCop pass to confirm no remaining offenses.

If erb_lint flags template issues (most likely indentation or trailing whitespace in the four new templates), fix inline and re-run.

- [ ] **Step 2: Update README**

Edit `README.md`. In the "Authentication" section (between the existing description of sign-in and the "Deploy" section), add a "Campaigns" sub-section. The current Authentication section ends with the password-reset paragraph; add this after it:

```markdown
### Campaigns

Campaign authoring lives on the admin subdomain at
`https://admin.gygaxagain.com/campaigns`. Each user owns their campaigns;
there is no sharing. The first time you sign in with no campaigns, you'll
land on the new-campaign form on admin.

The play surface for a campaign is at
`https://gygaxagain.com/campaigns/:id/play`. In Phase 3 this is a
placeholder; the real chat-style UI lands in Phase 6. Visiting a play URL
sets your `last_played_campaign_id`, so subsequent sign-ins drop you
straight back into that campaign.
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "$(cat <<'EOF'
Update README for Phase 3 (campaigns + play stub)

Documents the admin campaigns URL, the play surface placeholder, and
the last_played behavior driving the after-sign-in redirect. Refs #4.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 4: Deploy verification (optional, when ready)**

When deploying to Heroku:

```bash
git push heroku main
```

Heroku's release phase runs `bundle exec rails db:migrate` (configured in Phase 1). Verify in production:

1. Sign in at `https://gygaxagain.com/users/sign_in` as the alpha user.
2. (First sign-in, no campaigns) confirm you land on `https://admin.gygaxagain.com/campaigns/new`.
3. Create a campaign with a name and description.
4. Confirm the admin index shows it.
5. Navigate to `https://gygaxagain.com/campaigns/<id>/play`; confirm the placeholder renders.
6. Sign out, sign back in; confirm you land directly on the play placeholder (last-played path).
7. From admin, delete the campaign. Confirm `last_played_campaign_id` was nulled by signing out and back in — should land on admin new-campaign form again.

Acceptance criteria from #4 are satisfied when steps 1–7 pass in production.

---

## Self-review notes

**Spec coverage check:**

| Spec section | Implemented in |
|---|---|
| Schema: `campaigns` + `last_played_campaign_id` migrations | Tasks 1 + 2 |
| Validations (name presence, length, uniqueness scoped to user) | Task 1 |
| Associations + cascade behavior | Tasks 1 + 2 |
| Admin routes (`scope as: :admin`, `resources :campaigns, except: [:show]`) | Task 3 |
| `Admin::CampaignsController` all actions | Tasks 3–6 |
| Admin components (Index, Form) | Tasks 3, 4 |
| Play routes (`scope module: "play"`, `resources :campaigns, only: [:index]` + member `:play`) | Task 7 |
| `Play::CampaignsController` (index + play) | Tasks 7 + 8 |
| Play components (Picker, Placeholder) | Tasks 7 + 8 |
| `last_played_campaign_id` write via `update_column` | Task 8 |
| Three-case after-sign-in redirect + stale-id fall-through | Task 9 |
| Ownership 404 across admin and play | Covered in Tasks 5, 6, 8 |
| Redirect matrix spec | Task 9 |
| Ownership-check tests | Tasks 5, 6, 8 |
| End-to-end system spec | Task 10 |
| README update | Task 11 |
| Lookbook previews | Out — see "Spec deviation" at top of plan |

**No placeholders.** Every step has actual code or an exact command with expected output.

**Type / name consistency check:**
- Controller class names: `Admin::CampaignsController`, `Play::CampaignsController` — consistent across all tasks.
- Component class names: `Admin::Campaigns::IndexComponent`, `Admin::Campaigns::FormComponent`, `Play::Campaigns::PickerComponent`, `Play::Campaigns::PlaceholderComponent` — consistent.
- Route helpers used: `admin_campaigns_path`, `new_admin_campaign_path`, `edit_admin_campaign_path(id)`, `admin_campaign_path(id)`, `campaigns_path`, `play_campaign_path(id)`, `destroy_user_session_url(subdomain: "")` — all match the routes defined in Tasks 3 and 7.
- `current_user.update_column(:last_played_campaign_id, ...)` used consistently in Task 8 controller and Tasks 2/6/8/9 spec setup.
- `before_action :load_campaign` list grows from `[:edit, :update]` in Task 5 to `[:edit, :update, :destroy]` in Task 6 — explicit edit in Task 6.
- `subdomain: "admin"` vs `subdomain: ""` distinctions are consistent in the redirect logic (Task 9) and link helpers (Task 7 component sign-out, Task 8 component sign-out).
