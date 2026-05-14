# v2 Phase 6 — Play surface UI shell: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the chat-like play surface (scene picker + scene log + four event components dispatched by an explicit-registry module), the admin campaign show page with embedded scene CRUD (up/down reorder), and Lookbook previews. End-state: a signed-in admin can author a campaign → create scenes → switch to the play subdomain → pick a scene → see an (empty) scene log; component specs and asymmetry tests stay green.

**Architecture:** ViewComponent + Hotwire (Turbo) UI on Rails 8.1. Play and admin namespaces stay isolated; new admin controllers inherit from `Admin::ApplicationController` (Phase 4's base) to pick up the admin layout. `Play::Events::Component` is a module with a frozen REGISTRY hash mapping `Event#kind` strings to component classes; `.for(event)` dispatches per-row. Asymmetry tests on every `Play::*` component spec assert `not_to leak_secrets_of(faction, npc)` against rendered output.

**Tech Stack:** Rails 8.1 · ViewComponent · Hotwire (Turbo) · Tailwind CSS · Lookbook · `acts_as_list` · RSpec · Capybara · factory_bot · shoulda-matchers.

**Spec:** [`docs/superpowers/specs/2026-05-14-v2-phase-6-play-surface-ui-shell-design.md`](../specs/2026-05-14-v2-phase-6-play-surface-ui-shell-design.md).

**Issue:** [#7](https://github.com/barriault/gygaxagain/issues/7).

---

## File structure

**Routes + config (Task 1):**
- `config/routes/play.rb` — modified
- `config/routes/admin.rb` — modified
- `config/application.rb` — modified (ViewComponent preview path)

**Admin scene CRUD (Tasks 2-6):**
- `app/components/admin/scenes/form_component.{rb,html.erb}` — new
- `app/components/admin/scenes/row_component.{rb,html.erb}` — new
- `app/components/admin/campaigns/show_component.{rb,html.erb}` — new
- `app/components/admin/campaigns/index_component.html.erb` — modified (campaign name links to show)
- `app/controllers/admin/campaigns_controller.rb` — modified (add show action)
- `app/controllers/admin/scenes_controller.rb` — new
- `spec/components/admin/scenes/form_component_spec.rb` — new
- `spec/components/admin/scenes/row_component_spec.rb` — new
- `spec/components/admin/campaigns/show_component_spec.rb` — new
- `spec/requests/admin/campaigns_spec.rb` — modified (add show specs)
- `spec/requests/admin/scenes_spec.rb` — new

**Play campaign → scene picker (Tasks 7-8):**
- `app/components/play/campaigns/scene_picker_component.{rb,html.erb}` — new
- `app/components/play/campaigns/placeholder_component.html.erb` — modified (zero-scenes empty state)
- `app/components/play/campaigns/placeholder_component.rb` — unchanged (already accepts `campaign:`)
- `app/controllers/play/campaigns_controller.rb` — modified
- `spec/components/play/campaigns/scene_picker_component_spec.rb` — new
- `spec/components/play/campaigns/placeholder_component_spec.rb` — modified
- `spec/requests/play/campaigns_spec.rb` — modified

**Play event components + dispatcher (Tasks 9-13):**
- `app/components/play/events/narration_component.{rb,html.erb}` — new
- `app/components/play/events/dice_roll_component.{rb,html.erb}` — new
- `app/components/play/events/oracle_query_component.{rb,html.erb}` — new
- `app/components/play/events/scene_transition_component.{rb,html.erb}` — new
- `app/components/play/events/component.rb` — new (dispatcher module)
- `spec/components/play/events/narration_component_spec.rb` — new
- `spec/components/play/events/dice_roll_component_spec.rb` — new
- `spec/components/play/events/oracle_query_component_spec.rb` — new
- `spec/components/play/events/scene_transition_component_spec.rb` — new
- `spec/components/play/events/component_spec.rb` — new

**Play scene log + play surface (Tasks 14-16):**
- `app/components/play/scenes/log_component.{rb,html.erb}` — new
- `app/components/play/scenes/play_component.{rb,html.erb}` — new
- `app/controllers/play/scenes_controller.rb` — new
- `spec/components/play/scenes/log_component_spec.rb` — new
- `spec/components/play/scenes/play_component_spec.rb` — new
- `spec/requests/play/scenes_spec.rb` — new

**Lookbook previews (Task 17):**
- `spec/components/previews/play/events/narration_component_preview.rb` — new
- `spec/components/previews/play/events/dice_roll_component_preview.rb` — new
- `spec/components/previews/play/events/oracle_query_component_preview.rb` — new
- `spec/components/previews/play/events/scene_transition_component_preview.rb` — new
- `spec/components/previews/play/scenes/log_component_preview.rb` — new
- `spec/components/previews/play/campaigns/scene_picker_component_preview.rb` — new
- `spec/components/previews/admin/scenes/row_component_preview.rb` — new
- `spec/components/previews/admin/scenes/form_component_preview.rb` — new

**End-to-end + final pass (Tasks 18-19):**
- `spec/system/phase_6_play_surface_spec.rb` — new
- Polish, RuboCop, erb_lint, annotaterb refresh

---

## Task 1: Routes + Lookbook preview path config

**Files:**
- Modify: `config/routes/play.rb`
- Modify: `config/routes/admin.rb`
- Modify: `config/application.rb`

- [ ] **Step 1: Add nested scenes route under play campaigns**

Open `config/routes/play.rb`. Replace its body with:

```ruby
constraints subdomain: "" do
  devise_for :users, skip: [ :registrations ], controllers: { sessions: "users/sessions" }

  root "play/home#show"

  scope module: "play" do
    resources :campaigns, only: [ :index ] do
      member { get :play }

      resources :scenes, only: [] do
        member { get :play }
      end
    end
  end
end
```

- [ ] **Step 2: Verify the play routes resolve**

Run: `bin/rails routes -g scenes`
Expected: a row for `play_campaign_scene` with method GET, path `/campaigns/:campaign_id/scenes/:id/play`, controller `play/scenes#play`.

- [ ] **Step 3: Add show + nested scenes + move actions to admin campaigns**

Open `config/routes/admin.rb`. Replace its body with:

```ruby
constraints subdomain: "admin" do
  scope module: "admin", as: :admin do
    root to: redirect("/campaigns")

    resources :campaigns do
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

Note: the existing `resources :campaigns, except: [ :show ]` becomes `resources :campaigns` (show is now included).

- [ ] **Step 4: Verify the admin routes resolve**

Run: `bin/rails routes -g scenes`
Expected: rows for `admin_campaign_scenes` (GET/POST), `new_admin_campaign_scene` (GET), `edit_admin_campaign_scene` (GET), `admin_campaign_scene` (GET/PATCH/PUT/DELETE), `move_up_admin_campaign_scene` (POST), `move_down_admin_campaign_scene` (POST). Plus `admin_campaign` should appear (GET/PATCH/PUT/DELETE).

- [ ] **Step 5: Add the Lookbook preview path to application config**

Open `config/application.rb`. Inside `class Application < Rails::Application`, add the following line directly below `config.autoload_lib(ignore: %w[assets tasks])`:

```ruby
    config.view_component.preview_paths << Rails.root.join("spec/components/previews").to_s
```

The full block should now read:

```ruby
class Application < Rails::Application
  config.load_defaults 8.1

  config.autoload_lib(ignore: %w[assets tasks])

  config.view_component.preview_paths << Rails.root.join("spec/components/previews").to_s

  # ... existing comments and config below
```

- [ ] **Step 6: Verify the preview path is registered**

Run: `bin/rails runner "puts ViewComponent::Base.preview_paths.inspect"`
Expected: the output includes the path `/Users/barriault/dnd/gygaxagain/spec/components/previews`.

- [ ] **Step 7: Run the existing test suite to verify nothing regressed**

Run: `bundle exec rspec`
Expected: all existing specs pass (Phase 1–5 tests).

- [ ] **Step 8: Commit**

```bash
git add config/routes/play.rb config/routes/admin.rb config/application.rb
git commit -m "Add Phase 6 routes and Lookbook preview path (Phase 6.1)"
```

---

## Task 2: Admin::Scenes::FormComponent

Standalone form for new/edit scene. Mirrors the existing `Admin::Campaigns::FormComponent` pattern.

**Files:**
- Create: `app/components/admin/scenes/form_component.rb`
- Create: `app/components/admin/scenes/form_component.html.erb`
- Create: `spec/components/admin/scenes/form_component_spec.rb`

- [ ] **Step 1: Write the failing spec**

Create `spec/components/admin/scenes/form_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Admin::Scenes::FormComponent, type: :component do
  let(:campaign) { create(:campaign) }

  describe "for a new scene" do
    let(:scene) { campaign.scenes.build }

    it "renders the new-scene title and a Create button" do
      with_request_url(admin_campaign_scenes_path(campaign), host: "admin.gygaxagain.com") do
        render_inline(described_class.new(campaign: campaign, scene: scene))
      end

      expect(page).to have_text(/new scene/i)
      expect(page).to have_button("Create scene")
    end

    it "posts to admin_campaign_scenes_path" do
      with_request_url(admin_campaign_scenes_path(campaign), host: "admin.gygaxagain.com") do
        render_inline(described_class.new(campaign: campaign, scene: scene))
      end

      expect(page).to have_css("form[action='#{admin_campaign_scenes_path(campaign)}'][method='post']")
    end
  end

  describe "for an existing scene" do
    let(:scene) { create(:scene, campaign: campaign, title: "Existing", summary: "Existing summary") }

    it "renders the edit-scene title and an Update button" do
      with_request_url(edit_admin_campaign_scene_path(campaign, scene), host: "admin.gygaxagain.com") do
        render_inline(described_class.new(campaign: campaign, scene: scene))
      end

      expect(page).to have_text(/edit scene/i)
      expect(page).to have_button("Update scene")
      expect(page).to have_field("Title", with: "Existing")
      expect(page).to have_field("Summary", with: "Existing summary")
    end
  end

  describe "with validation errors" do
    let(:scene) do
      s = campaign.scenes.build(title: "")
      s.valid?
      s
    end

    it "renders inline error messages" do
      with_request_url(admin_campaign_scenes_path(campaign), host: "admin.gygaxagain.com") do
        render_inline(described_class.new(campaign: campaign, scene: scene))
      end

      expect(page).to have_text(/can't be blank/i)
    end
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/components/admin/scenes/form_component_spec.rb`
Expected: failure with `NameError: uninitialized constant Admin::Scenes::FormComponent`.

- [ ] **Step 3: Write the component class**

Create `app/components/admin/scenes/form_component.rb`:

```ruby
module Admin
  module Scenes
    class FormComponent < ViewComponent::Base
      def initialize(campaign:, scene:)
        @campaign = campaign
        @scene = scene
      end

      attr_reader :campaign, :scene

      def form_url
        if scene.persisted?
          helpers.admin_campaign_scene_path(campaign, scene)
        else
          helpers.admin_campaign_scenes_path(campaign)
        end
      end

      def form_method
        scene.persisted? ? :patch : :post
      end

      def submit_label
        scene.persisted? ? "Update scene" : "Create scene"
      end

      def header
        scene.persisted? ? "Edit scene" : "New scene"
      end
    end
  end
end
```

- [ ] **Step 4: Write the ERB template**

Create `app/components/admin/scenes/form_component.html.erb`:

```erb
<div class="min-h-screen bg-slate-900 text-slate-100 px-4 py-12">
  <div class="mx-auto max-w-xl">
    <h1 class="text-3xl font-bold tracking-tight"><%= header %></h1>

    <% if scene.errors.any? %>
      <div class="mt-6 rounded border border-rose-700 bg-rose-950/40 px-4 py-3 text-sm text-rose-200">
        <p class="font-semibold">
          <%= pluralize(scene.errors.count, "error") %> prohibited this scene from being saved:
        </p>
        <ul class="mt-2 list-disc pl-5">
          <% scene.errors.full_messages.each do |msg| %>
            <li><%= msg %></li>
          <% end %>
        </ul>
      </div>
    <% end %>

    <%= form_with model: scene, url: form_url, method: form_method, local: true, class: "mt-8 space-y-6" do |f| %>
      <div>
        <%= f.label :title, class: "block text-sm uppercase tracking-widest text-slate-400" %>
        <%= f.text_field :title,
                         class: "mt-2 w-full rounded bg-slate-800 px-3 py-2 text-slate-100 focus:outline-none focus:ring-2 focus:ring-slate-500" %>
      </div>

      <div>
        <%= f.label :summary, class: "block text-sm uppercase tracking-widest text-slate-400" %>
        <%= f.text_area :summary,
                        rows: 4,
                        class: "mt-2 w-full rounded bg-slate-800 px-3 py-2 text-slate-100 focus:outline-none focus:ring-2 focus:ring-slate-500" %>
      </div>

      <div class="flex items-center gap-4">
        <%= f.submit submit_label,
                     class: "rounded bg-slate-100 px-4 py-2 text-sm font-semibold text-slate-900 hover:bg-white" %>
        <%= link_to "Cancel",
                    helpers.admin_campaign_path(campaign),
                    class: "text-sm text-slate-400 hover:text-slate-200" %>
      </div>
    <% end %>
  </div>
</div>
```

- [ ] **Step 5: Run the spec to verify it passes**

Run: `bundle exec rspec spec/components/admin/scenes/form_component_spec.rb`
Expected: 4 examples, 0 failures.

If the `with_request_url` helper isn't recognized, your version of `view_component` may use `with_controller_class` instead, or you may need to wrap the render in a `setup_request_url` block. Alternative pattern: stub the routes context by passing `host` to capybara via `Capybara.app_host = "http://admin.gygaxagain.com"` before the render. If neither works, fall back to plain `render_inline` and assert via CSS selectors on the rendered HTML (`page.has_css?(...)`).

- [ ] **Step 6: Run the full suite**

Run: `bundle exec rspec`
Expected: green.

- [ ] **Step 7: Commit**

```bash
git add app/components/admin/scenes/form_component.rb app/components/admin/scenes/form_component.html.erb spec/components/admin/scenes/form_component_spec.rb
git commit -m "Add Admin::Scenes::FormComponent (Phase 6.2)"
```

---

## Task 3: Admin::Scenes::RowComponent

A single row in the scene list, with up/down/edit/delete buttons. Standalone — used inside `Admin::Campaigns::ShowComponent`.

**Files:**
- Create: `app/components/admin/scenes/row_component.rb`
- Create: `app/components/admin/scenes/row_component.html.erb`
- Create: `spec/components/admin/scenes/row_component_spec.rb`

- [ ] **Step 1: Write the failing spec**

Create `spec/components/admin/scenes/row_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Admin::Scenes::RowComponent, type: :component do
  let(:campaign) { create(:campaign) }
  let!(:first_scene)  { create(:scene, campaign: campaign, title: "First",  summary: "First summary") }
  let!(:middle_scene) { create(:scene, campaign: campaign, title: "Middle", summary: "Middle summary") }
  let!(:last_scene)   { create(:scene, campaign: campaign, title: "Last",   summary: "Last summary") }

  it "renders the scene title and a truncated summary" do
    render_inline(described_class.new(scene: middle_scene))

    expect(page).to have_text("Middle")
    expect(page).to have_text("Middle summary")
  end

  it "renders Edit and Delete affordances" do
    render_inline(described_class.new(scene: middle_scene))

    expect(page).to have_link("Edit")
    expect(page).to have_button("Delete")
  end

  it "renders Up and Down buttons for a middle scene" do
    render_inline(described_class.new(scene: middle_scene))

    expect(page).to have_button("Up")
    expect(page).to have_button("Down")
  end

  it "disables Up for the first scene" do
    render_inline(described_class.new(scene: first_scene))

    expect(page).to have_button("Up", disabled: true)
    expect(page).to have_button("Down", disabled: false)
  end

  it "disables Down for the last scene" do
    render_inline(described_class.new(scene: last_scene))

    expect(page).to have_button("Up", disabled: false)
    expect(page).to have_button("Down", disabled: true)
  end

  it "renders the edit link to the edit path" do
    render_inline(described_class.new(scene: middle_scene))

    expect(page).to have_link("Edit", href: edit_admin_campaign_scene_path(campaign, middle_scene))
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/components/admin/scenes/row_component_spec.rb`
Expected: failure with `NameError: uninitialized constant Admin::Scenes::RowComponent`.

- [ ] **Step 3: Write the component class**

Create `app/components/admin/scenes/row_component.rb`:

```ruby
module Admin
  module Scenes
    class RowComponent < ViewComponent::Base
      def initialize(scene:)
        @scene = scene
      end

      attr_reader :scene

      def campaign
        scene.campaign
      end

      def first?
        scene.first?
      end

      def last?
        scene.last?
      end
    end
  end
end
```

- [ ] **Step 4: Write the ERB template**

Create `app/components/admin/scenes/row_component.html.erb`:

```erb
<li class="py-4 flex items-start justify-between gap-4">
  <div class="flex-1 min-w-0">
    <p class="text-lg font-semibold"><%= scene.title %></p>
    <% if scene.summary.present? %>
      <p class="mt-1 text-sm text-slate-400 line-clamp-2"><%= scene.summary %></p>
    <% end %>
  </div>
  <div class="flex items-center gap-2 shrink-0">
    <%= button_to "Up",
                  helpers.move_up_admin_campaign_scene_path(campaign, scene),
                  method: :post,
                  disabled: first?,
                  class: "rounded px-2 py-1 text-xs text-slate-300 hover:text-white disabled:opacity-30 disabled:cursor-not-allowed bg-slate-800" %>
    <%= button_to "Down",
                  helpers.move_down_admin_campaign_scene_path(campaign, scene),
                  method: :post,
                  disabled: last?,
                  class: "rounded px-2 py-1 text-xs text-slate-300 hover:text-white disabled:opacity-30 disabled:cursor-not-allowed bg-slate-800" %>
    <%= link_to "Edit",
                helpers.edit_admin_campaign_scene_path(campaign, scene),
                class: "text-sm text-slate-300 hover:text-slate-100" %>
    <%= button_to "Delete",
                  helpers.admin_campaign_scene_path(campaign, scene),
                  method: :delete,
                  data: { turbo_confirm: "Delete '#{scene.title}'? This cannot be undone." },
                  class: "text-sm text-rose-400 hover:text-rose-200" %>
  </div>
</li>
```

- [ ] **Step 5: Run the spec to verify it passes**

Run: `bundle exec rspec spec/components/admin/scenes/row_component_spec.rb`
Expected: 6 examples, 0 failures.

- [ ] **Step 6: Run the full suite**

Run: `bundle exec rspec`
Expected: green.

- [ ] **Step 7: Commit**

```bash
git add app/components/admin/scenes/row_component.rb app/components/admin/scenes/row_component.html.erb spec/components/admin/scenes/row_component_spec.rb
git commit -m "Add Admin::Scenes::RowComponent (Phase 6.3)"
```

---

## Task 4: Admin::CampaignsController#show + Admin::Campaigns::ShowComponent (skeleton)

Skeleton show page with campaign metadata only. The scenes list lands in Task 6 once `Admin::ScenesController` exists. This step adds the navigation entry point and the show action.

**Files:**
- Modify: `app/controllers/admin/campaigns_controller.rb`
- Modify: `app/components/admin/campaigns/index_component.html.erb`
- Create: `app/components/admin/campaigns/show_component.rb`
- Create: `app/components/admin/campaigns/show_component.html.erb`
- Create: `spec/components/admin/campaigns/show_component_spec.rb`
- Modify: `spec/requests/admin/campaigns_spec.rb`

- [ ] **Step 1: Write the failing show-component spec**

Create `spec/components/admin/campaigns/show_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Admin::Campaigns::ShowComponent, type: :component do
  let(:campaign) { create(:campaign, name: "Curse of Strahd", description: "Gothic horror.") }

  it "renders the campaign name and description" do
    render_inline(described_class.new(campaign: campaign))

    expect(page).to have_text("Curse of Strahd")
    expect(page).to have_text("Gothic horror.")
  end

  it "renders a Scenes section header" do
    render_inline(described_class.new(campaign: campaign))

    expect(page).to have_text(/scenes/i)
  end

  it "renders a 'New scene' link" do
    render_inline(described_class.new(campaign: campaign))

    expect(page).to have_link("New scene", href: new_admin_campaign_scene_path(campaign))
  end

  it "renders an empty state when the campaign has no scenes" do
    render_inline(described_class.new(campaign: campaign))

    expect(page).to have_text(/no scenes yet/i)
  end

  it "renders a Back-to-campaigns link" do
    render_inline(described_class.new(campaign: campaign))

    expect(page).to have_link("Back to campaigns", href: admin_campaigns_path)
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/components/admin/campaigns/show_component_spec.rb`
Expected: failure with `NameError: uninitialized constant Admin::Campaigns::ShowComponent`.

- [ ] **Step 3: Write the component class**

Create `app/components/admin/campaigns/show_component.rb`:

```ruby
module Admin
  module Campaigns
    class ShowComponent < ViewComponent::Base
      def initialize(campaign:)
        @campaign = campaign
      end

      attr_reader :campaign

      def scenes
        @scenes ||= campaign.scenes.order(:position)
      end
    end
  end
end
```

- [ ] **Step 4: Write the ERB template (skeleton — scenes list added in Task 6)**

Create `app/components/admin/campaigns/show_component.html.erb`:

```erb
<div class="min-h-screen bg-slate-900 text-slate-100 px-4 py-12">
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

    <div class="mt-10">
      <div class="flex items-center justify-between">
        <h2 class="text-xl font-semibold">Scenes</h2>
        <%= link_to "New scene",
                    helpers.new_admin_campaign_scene_path(campaign),
                    class: "text-sm uppercase tracking-widest text-slate-300 hover:text-slate-100" %>
      </div>

      <% if scenes.any? %>
        <ul class="mt-6 divide-y divide-slate-800">
          <%# Task 6 renders Admin::Scenes::RowComponent here %>
        </ul>
      <% else %>
        <p class="mt-8 text-slate-400">No scenes yet. Create one to start playing.</p>
      <% end %>
    </div>
  </div>
</div>
```

- [ ] **Step 5: Run the spec to verify it passes**

Run: `bundle exec rspec spec/components/admin/campaigns/show_component_spec.rb`
Expected: 5 examples, 0 failures.

- [ ] **Step 6: Add the show action to the controller**

Open `app/controllers/admin/campaigns_controller.rb`. The existing controller has a `before_action :load_campaign, only: [ :edit, :update, :destroy ]` declaration at the top and a private `load_campaign` method that sets `@campaign = current_user.campaigns.find(params[:id])`. Make two changes:

1. Update the `before_action` line to include `:show`:

```ruby
    before_action :load_campaign, only: [ :show, :edit, :update, :destroy ]
```

2. Add the `def show` action between `def index` and `def new`:

```ruby
    def show
      render Admin::Campaigns::ShowComponent.new(campaign: @campaign)
    end
```

`@campaign` is set by the before_action — no inline find needed.

- [ ] **Step 7: Add a request spec for the show action**

Open `spec/requests/admin/campaigns_spec.rb`. Inside the top-level `RSpec.describe "Admin::Campaigns", type: :request do` block, append:

```ruby
  describe "GET /campaigns/:id" do
    let(:campaign) { create(:campaign, user: user, name: "Curse of Strahd") }
    let(:other_user) { create(:user) }
    let(:other_campaign) { create(:campaign, user: other_user) }

    context "authenticated" do
      before { sign_in user }

      it "renders the show page for the user's campaign" do
        get "/campaigns/#{campaign.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Curse of Strahd")
      end

      it "404s for another user's campaign" do
        expect {
          get "/campaigns/#{other_campaign.id}"
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "unauthenticated" do
      it "redirects to apex sign-in" do
        get "/campaigns/#{campaign.id}"

        expect(response).to have_http_status(:found)
        expect(response.location).to include("gygaxagain.com/users/sign_in")
      end
    end
  end
```

- [ ] **Step 8: Update the index component to link campaign names to show**

Open `app/components/admin/campaigns/index_component.html.erb`. Find the line:

```erb
              <p class="text-lg font-semibold"><%= campaign.name %></p>
```

Replace with:

```erb
              <p class="text-lg font-semibold">
                <%= link_to campaign.name, helpers.admin_campaign_path(campaign), class: "hover:underline" %>
              </p>
```

- [ ] **Step 9: Run the request specs**

Run: `bundle exec rspec spec/requests/admin/campaigns_spec.rb`
Expected: existing specs still pass plus 3 new examples (1 ok + 1 404 + 1 unauth).

- [ ] **Step 10: Run the full suite**

Run: `bundle exec rspec`
Expected: green.

- [ ] **Step 11: Commit**

```bash
git add app/controllers/admin/campaigns_controller.rb app/components/admin/campaigns spec/components/admin/campaigns/show_component_spec.rb spec/requests/admin/campaigns_spec.rb
git commit -m "Add Admin::CampaignsController#show with skeleton ShowComponent (Phase 6.4)"
```

---

## Task 5: Admin::ScenesController + request specs

Full CRUD + move_up/move_down. The controller redirects to `admin_campaign_path` (the show page added in Task 4) on every successful action.

**Files:**
- Create: `app/controllers/admin/scenes_controller.rb`
- Create: `spec/requests/admin/scenes_spec.rb`

- [ ] **Step 1: Write the failing request spec**

Create `spec/requests/admin/scenes_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Admin::Scenes", type: :request do
  before { host! "admin.gygaxagain.com" }

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:campaign) { create(:campaign, user: user) }

  describe "GET /campaigns/:campaign_id/scenes/new" do
    context "authenticated" do
      before { sign_in user }

      it "renders the form" do
        get "/campaigns/#{campaign.id}/scenes/new"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("New scene")
      end
    end

    context "unauthenticated" do
      it "redirects to apex sign-in" do
        get "/campaigns/#{campaign.id}/scenes/new"
        expect(response).to have_http_status(:found)
        expect(response.location).to include("gygaxagain.com/users/sign_in")
      end
    end
  end

  describe "POST /campaigns/:campaign_id/scenes" do
    before { sign_in user }

    it "creates the scene and redirects to the campaign show page" do
      expect {
        post "/campaigns/#{campaign.id}/scenes",
             params: { scene: { title: "Tavern at Dusk", summary: "Rainy, quiet." } }
      }.to change { campaign.scenes.count }.by(1)

      expect(response).to redirect_to("/campaigns/#{campaign.id}")
      follow_redirect!
      expect(response.body).to include("Tavern at Dusk")
    end

    it "re-renders the form on validation failure" do
      post "/campaigns/#{campaign.id}/scenes",
           params: { scene: { title: "", summary: "Empty title" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(/can't be blank/i.source)
    end
  end

  describe "GET /campaigns/:campaign_id/scenes/:id/edit" do
    let!(:scene) { create(:scene, campaign: campaign, title: "Existing") }

    before { sign_in user }

    it "renders the edit form prefilled" do
      get "/campaigns/#{campaign.id}/scenes/#{scene.id}/edit"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Edit scene")
      expect(response.body).to include("Existing")
    end
  end

  describe "PATCH /campaigns/:campaign_id/scenes/:id" do
    let!(:scene) { create(:scene, campaign: campaign, title: "Old") }

    before { sign_in user }

    it "updates the scene and redirects to the campaign show page" do
      patch "/campaigns/#{campaign.id}/scenes/#{scene.id}",
            params: { scene: { title: "New", summary: "Updated" } }

      expect(response).to redirect_to("/campaigns/#{campaign.id}")
      expect(scene.reload.title).to eq("New")
      expect(scene.reload.summary).to eq("Updated")
    end
  end

  describe "DELETE /campaigns/:campaign_id/scenes/:id" do
    let!(:scene) { create(:scene, campaign: campaign) }

    before { sign_in user }

    it "deletes the scene and redirects to the campaign show page" do
      expect {
        delete "/campaigns/#{campaign.id}/scenes/#{scene.id}"
      }.to change { campaign.scenes.count }.by(-1)

      expect(response).to redirect_to("/campaigns/#{campaign.id}")
    end
  end

  describe "POST /campaigns/:campaign_id/scenes/:id/move_up + move_down" do
    let!(:first_scene)  { create(:scene, campaign: campaign, title: "First") }
    let!(:second_scene) { create(:scene, campaign: campaign, title: "Second") }

    before { sign_in user }

    it "move_up swaps positions and redirects" do
      post "/campaigns/#{campaign.id}/scenes/#{second_scene.id}/move_up"

      expect(response).to redirect_to("/campaigns/#{campaign.id}")
      expect(first_scene.reload.position).to eq(2)
      expect(second_scene.reload.position).to eq(1)
    end

    it "move_down swaps positions and redirects" do
      post "/campaigns/#{campaign.id}/scenes/#{first_scene.id}/move_down"

      expect(response).to redirect_to("/campaigns/#{campaign.id}")
      expect(first_scene.reload.position).to eq(2)
      expect(second_scene.reload.position).to eq(1)
    end

    it "move_up at the top is a no-op (idempotent)" do
      original_position = first_scene.position
      post "/campaigns/#{campaign.id}/scenes/#{first_scene.id}/move_up"

      expect(response).to redirect_to("/campaigns/#{campaign.id}")
      expect(first_scene.reload.position).to eq(original_position)
    end
  end

  describe "GET /campaigns/:campaign_id/scenes (index)" do
    before { sign_in user }

    it "redirects to the campaign show page" do
      get "/campaigns/#{campaign.id}/scenes"

      expect(response).to redirect_to("/campaigns/#{campaign.id}")
    end
  end

  describe "tenant scoping" do
    let(:other_campaign) { create(:campaign, user: other_user) }
    let!(:scene) { create(:scene, campaign: other_campaign) }

    before { sign_in user }

    it "404s on accessing a scene of another user's campaign" do
      expect {
        get "/campaigns/#{other_campaign.id}/scenes/#{scene.id}/edit"
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/requests/admin/scenes_spec.rb`
Expected: failure on the first example, likely `ActionController::RoutingError` or `NameError: uninitialized constant Admin::ScenesController`.

- [ ] **Step 3: Write the controller**

Create `app/controllers/admin/scenes_controller.rb`:

```ruby
module Admin
  class ScenesController < Admin::ApplicationController
    before_action :load_campaign
    before_action :load_scene, only: [ :edit, :update, :destroy, :move_up, :move_down ]

    def index
      redirect_to admin_campaign_path(@campaign)
    end

    def new
      @scene = @campaign.scenes.build
      render Admin::Scenes::FormComponent.new(campaign: @campaign, scene: @scene)
    end

    def create
      @scene = @campaign.scenes.build(scene_params)
      if @scene.save
        redirect_to admin_campaign_path(@campaign), notice: "Scene created."
      else
        render Admin::Scenes::FormComponent.new(campaign: @campaign, scene: @scene),
               status: :unprocessable_entity
      end
    end

    def edit
      render Admin::Scenes::FormComponent.new(campaign: @campaign, scene: @scene)
    end

    def update
      if @scene.update(scene_params)
        redirect_to admin_campaign_path(@campaign), notice: "Scene updated."
      else
        render Admin::Scenes::FormComponent.new(campaign: @campaign, scene: @scene),
               status: :unprocessable_entity
      end
    end

    def destroy
      @scene.destroy
      redirect_to admin_campaign_path(@campaign), notice: "Scene deleted."
    end

    def move_up
      @scene.move_higher
      redirect_to admin_campaign_path(@campaign)
    end

    def move_down
      @scene.move_lower
      redirect_to admin_campaign_path(@campaign)
    end

    private

    def load_campaign
      @campaign = current_user.campaigns.find(params[:campaign_id])
    end

    def load_scene
      @scene = @campaign.scenes.find(params[:id])
    end

    def scene_params
      params.require(:scene).permit(:title, :summary)
    end
  end
end
```

- [ ] **Step 4: Run the spec to verify it passes**

Run: `bundle exec rspec spec/requests/admin/scenes_spec.rb`
Expected: ~12 examples, 0 failures.

- [ ] **Step 5: Run the full suite**

Run: `bundle exec rspec`
Expected: green.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/admin/scenes_controller.rb spec/requests/admin/scenes_spec.rb
git commit -m "Add Admin::ScenesController with CRUD and move actions (Phase 6.5)"
```

---

## Task 6: Wire Admin::Scenes::RowComponent into Admin::Campaigns::ShowComponent

Replace the placeholder comment with rendered scene rows. Update the show-component spec to assert the scene list.

**Files:**
- Modify: `app/components/admin/campaigns/show_component.html.erb`
- Modify: `spec/components/admin/campaigns/show_component_spec.rb`

- [ ] **Step 1: Add a failing spec example for the scene list**

Open `spec/components/admin/campaigns/show_component_spec.rb`. After the existing `it "renders an empty state..."` example, add:

```ruby
  describe "with scenes" do
    let!(:scene_a) { create(:scene, campaign: campaign, title: "Scene Alpha") }
    let!(:scene_b) { create(:scene, campaign: campaign, title: "Scene Beta") }

    it "renders each scene as a row" do
      render_inline(described_class.new(campaign: campaign))

      expect(page).to have_text("Scene Alpha")
      expect(page).to have_text("Scene Beta")
    end

    it "does NOT render the empty-state copy" do
      render_inline(described_class.new(campaign: campaign))

      expect(page).not_to have_text(/no scenes yet/i)
    end
  end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/components/admin/campaigns/show_component_spec.rb`
Expected: 2 new failing examples (the rendered HTML doesn't include "Scene Alpha" or "Scene Beta" yet — they're in the placeholder comment).

- [ ] **Step 3: Replace the placeholder comment with the row component**

Open `app/components/admin/campaigns/show_component.html.erb`. Find the line:

```erb
          <%# Task 6 renders Admin::Scenes::RowComponent here %>
```

Replace with:

```erb
          <% scenes.each do |scene| %>
            <%= render Admin::Scenes::RowComponent.new(scene: scene) %>
          <% end %>
```

- [ ] **Step 4: Run the spec to verify it passes**

Run: `bundle exec rspec spec/components/admin/campaigns/show_component_spec.rb`
Expected: 7 examples (5 original + 2 new), 0 failures.

- [ ] **Step 5: Run the full suite**

Run: `bundle exec rspec`
Expected: green.

- [ ] **Step 6: Commit**

```bash
git add app/components/admin/campaigns/show_component.html.erb spec/components/admin/campaigns/show_component_spec.rb
git commit -m "Wire Admin::Scenes::RowComponent into ShowComponent (Phase 6.6)"
```

---

## Task 7: Play::Campaigns::ScenePickerComponent + Placeholder update

The scene picker (when scenes exist) and the retargeted placeholder (zero-scenes empty state).

**Files:**
- Create: `app/components/play/campaigns/scene_picker_component.rb`
- Create: `app/components/play/campaigns/scene_picker_component.html.erb`
- Modify: `app/components/play/campaigns/placeholder_component.html.erb`
- Create: `spec/components/play/campaigns/scene_picker_component_spec.rb`
- Modify: `spec/components/play/campaigns/placeholder_component_spec.rb`

- [ ] **Step 1: Write the failing ScenePickerComponent spec**

Create `spec/components/play/campaigns/scene_picker_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Play::Campaigns::ScenePickerComponent, type: :component do
  let(:campaign) { create(:campaign, name: "Curse of Strahd") }
  let!(:scene_one) { create(:scene, campaign: campaign, title: "Tavern", summary: "Rainy.") }
  let!(:scene_two) { create(:scene, campaign: campaign, title: "Forest", summary: "Misty.") }

  it "renders the campaign name as a header" do
    render_inline(described_class.new(campaign: campaign))

    expect(page).to have_text("Curse of Strahd")
  end

  it "renders one link per scene" do
    render_inline(described_class.new(campaign: campaign))

    expect(page).to have_link("Tavern", href: play_campaign_scene_path(campaign, scene_one))
    expect(page).to have_link("Forest", href: play_campaign_scene_path(campaign, scene_two))
  end

  it "renders summaries beneath each title" do
    render_inline(described_class.new(campaign: campaign))

    expect(page).to have_text("Rainy.")
    expect(page).to have_text("Misty.")
  end

  describe "asymmetry" do
    let(:faction) { create(:faction, campaign: campaign) }
    let(:npc)     { create(:npc, campaign: campaign) }

    before do
      create(:faction_secret, faction: faction, label: "hidden temple", content: "in the swamp")
      create(:npc_secret,     npc: npc,         label: "true identity", content: "is a doppelganger")
    end

    it "does not leak secrets of related records" do
      rendered = render_inline(described_class.new(campaign: campaign)).to_s
      expect(rendered).not_to leak_secrets_of(faction, npc)
    end
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/components/play/campaigns/scene_picker_component_spec.rb`
Expected: failure with `NameError: uninitialized constant Play::Campaigns::ScenePickerComponent`.

- [ ] **Step 3: Write the component class**

Create `app/components/play/campaigns/scene_picker_component.rb`:

```ruby
module Play
  module Campaigns
    class ScenePickerComponent < ViewComponent::Base
      def initialize(campaign:)
        @campaign = campaign
      end

      attr_reader :campaign

      def scenes
        @scenes ||= campaign.scenes.order(:position)
      end
    end
  end
end
```

- [ ] **Step 4: Write the ERB template**

Create `app/components/play/campaigns/scene_picker_component.html.erb`:

```erb
<div class="min-h-screen bg-slate-900 text-slate-100 px-4 py-12">
  <div class="mx-auto max-w-xl">
    <p class="text-xs uppercase tracking-widest text-slate-500">Now playing</p>
    <h1 class="mt-2 text-3xl font-bold tracking-tight"><%= campaign.name %></h1>

    <h2 class="mt-10 text-lg font-semibold">Choose a scene</h2>

    <ul class="mt-4 space-y-3">
      <% scenes.each do |scene| %>
        <li>
          <%= link_to helpers.play_campaign_scene_path(campaign, scene),
                      class: "block rounded bg-slate-800 px-4 py-3 hover:bg-slate-700" do %>
            <p class="font-semibold"><%= scene.title %></p>
            <% if scene.summary.present? %>
              <p class="mt-1 text-sm text-slate-400 line-clamp-2"><%= scene.summary %></p>
            <% end %>
          <% end %>
        </li>
      <% end %>
    </ul>

    <div class="mt-12">
      <%= link_to "Back to campaigns",
                  helpers.campaigns_path,
                  class: "text-sm text-slate-400 hover:text-slate-200" %>
    </div>
  </div>
</div>
```

- [ ] **Step 5: Run the spec to verify it passes**

Run: `bundle exec rspec spec/components/play/campaigns/scene_picker_component_spec.rb`
Expected: 4 examples, 0 failures.

- [ ] **Step 6: Update the placeholder component template to be a zero-scenes empty state**

Open `app/components/play/campaigns/placeholder_component.html.erb`. Replace the entire file with:

```erb
<div class="min-h-screen bg-slate-900 text-slate-100 px-4 py-12">
  <div class="mx-auto max-w-xl">
    <p class="text-xs uppercase tracking-widest text-slate-500">Now playing</p>
    <h1 class="mt-2 text-3xl font-bold tracking-tight"><%= campaign.name %></h1>

    <p class="mt-8 text-slate-300">
      No scenes yet. Create one in admin to start playing.
    </p>

    <div class="mt-12">
      <%= link_to "Back to campaigns",
                  helpers.campaigns_path,
                  class: "text-sm text-slate-300 hover:text-slate-100" %>
    </div>
  </div>
</div>
```

- [ ] **Step 7: Update the placeholder spec**

Open `spec/components/play/campaigns/placeholder_component_spec.rb`. Replace its body with:

```ruby
require "rails_helper"

RSpec.describe Play::Campaigns::PlaceholderComponent, type: :component do
  let(:campaign) { create(:campaign, name: "Curse of Strahd") }

  it "renders the campaign name" do
    render_inline(described_class.new(campaign: campaign))

    expect(page).to have_text("Curse of Strahd")
  end

  it "renders the no-scenes empty-state message" do
    render_inline(described_class.new(campaign: campaign))

    expect(page).to have_text(/no scenes yet/i)
  end

  it "renders a back-to-campaigns link" do
    render_inline(described_class.new(campaign: campaign))

    expect(page).to have_link("Back to campaigns", href: campaigns_path)
  end

  describe "asymmetry" do
    let(:faction) { create(:faction, campaign: campaign) }
    let(:npc)     { create(:npc, campaign: campaign) }

    before do
      create(:faction_secret, faction: faction, label: "hidden temple", content: "in the swamp")
      create(:npc_secret,     npc: npc,         label: "true identity", content: "is a doppelganger")
    end

    it "does not leak secrets of related records" do
      rendered = render_inline(described_class.new(campaign: campaign)).to_s
      expect(rendered).not_to leak_secrets_of(faction, npc)
    end
  end
end
```

- [ ] **Step 8: Run the placeholder spec to verify it passes**

Run: `bundle exec rspec spec/components/play/campaigns/placeholder_component_spec.rb`
Expected: 4 examples, 0 failures.

- [ ] **Step 9: Run the full suite**

Run: `bundle exec rspec`
Expected: green.

- [ ] **Step 10: Commit**

```bash
git add app/components/play/campaigns spec/components/play/campaigns
git commit -m "Add ScenePickerComponent and retarget Placeholder as zero-scenes empty state (Phase 6.7)"
```

---

## Task 8: Play::CampaignsController#play update (picker vs placeholder)

The action picks between `ScenePickerComponent` (scenes exist) and `PlaceholderComponent` (no scenes).

**Files:**
- Modify: `app/controllers/play/campaigns_controller.rb`
- Modify: `spec/requests/play/campaigns_spec.rb`

- [ ] **Step 1: Update the spec to cover both branches**

Open `spec/requests/play/campaigns_spec.rb`. Find the `describe "GET /campaigns/:id/play"` block. Locate the authenticated `it` block (currently asserts the placeholder renders). Replace the entire authenticated context block with:

```ruby
    context "authenticated" do
      before { sign_in user }

      it "renders the scene picker when the campaign has scenes" do
        campaign = create(:campaign, user: user)
        create(:scene, campaign: campaign, title: "Tavern")

        get "/campaigns/#{campaign.id}/play"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Choose a scene")
        expect(response.body).to include("Tavern")
      end

      it "renders the empty-state placeholder when the campaign has no scenes" do
        campaign = create(:campaign, user: user)

        get "/campaigns/#{campaign.id}/play"

        expect(response).to have_http_status(:ok)
        expect(response.body).to match(/no scenes yet/i)
      end

      it "updates last_played_campaign_id regardless of scene count" do
        campaign = create(:campaign, user: user)

        get "/campaigns/#{campaign.id}/play"

        expect(user.reload.last_played_campaign_id).to eq(campaign.id)
      end

      it "404s for another user's campaign" do
        other = create(:campaign, user: other_user)

        expect {
          get "/campaigns/#{other.id}/play"
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
```

- [ ] **Step 2: Run the spec to verify it fails on the new scene-picker case**

Run: `bundle exec rspec spec/requests/play/campaigns_spec.rb`
Expected: the "scene picker when scenes exist" example fails — the body doesn't contain "Choose a scene" because the action always renders the placeholder.

- [ ] **Step 3: Update the controller to branch on scene presence**

Open `app/controllers/play/campaigns_controller.rb`. Replace the `play` action body with:

```ruby
    def play
      @campaign = current_user.campaigns.find(params[:id])
      current_user.update_column(:last_played_campaign_id, @campaign.id)

      if @campaign.scenes.any?
        render Play::Campaigns::ScenePickerComponent.new(campaign: @campaign)
      else
        render Play::Campaigns::PlaceholderComponent.new(campaign: @campaign)
      end
    end
```

- [ ] **Step 4: Run the spec to verify it passes**

Run: `bundle exec rspec spec/requests/play/campaigns_spec.rb`
Expected: green.

- [ ] **Step 5: Run the full suite**

Run: `bundle exec rspec`
Expected: green.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/play/campaigns_controller.rb spec/requests/play/campaigns_spec.rb
git commit -m "Branch Play::CampaignsController#play on scene presence (Phase 6.8)"
```

---

## Task 9: Play::Events::NarrationComponent

The first event component. Establishes the pattern (component class + ERB + spec + asymmetry test) that Tasks 10–12 replicate.

**Files:**
- Create: `app/components/play/events/narration_component.rb`
- Create: `app/components/play/events/narration_component.html.erb`
- Create: `spec/components/play/events/narration_component_spec.rb`

- [ ] **Step 1: Write the failing spec**

Create `spec/components/play/events/narration_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Play::Events::NarrationComponent, type: :component do
  let(:campaign) { create(:campaign) }
  let(:scene)    { create(:scene, campaign: campaign) }
  let(:event) do
    create(:event,
           scene: scene,
           kind: "narration",
           payload: { "text" => "The tavern is quiet. Rain drips from the eaves." },
           occurred_at: 5.minutes.ago)
  end

  it "renders the narration text" do
    render_inline(described_class.new(event: event))

    expect(page).to have_text("The tavern is quiet. Rain drips from the eaves.")
  end

  it "renders a relative timestamp" do
    render_inline(described_class.new(event: event))

    expect(page).to have_text(/ago/)
  end

  describe "asymmetry" do
    let(:faction) { create(:faction, campaign: campaign) }
    let(:npc)     { create(:npc, campaign: campaign) }

    before do
      create(:faction_secret, faction: faction, label: "hidden temple", content: "in the swamp")
      create(:npc_secret,     npc: npc,         label: "true identity", content: "is a doppelganger")
    end

    it "does not leak secrets of related records" do
      rendered = render_inline(described_class.new(event: event)).to_s
      expect(rendered).not_to leak_secrets_of(faction, npc)
    end
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/components/play/events/narration_component_spec.rb`
Expected: failure with `NameError: uninitialized constant Play::Events::NarrationComponent`.

- [ ] **Step 3: Write the component class**

Create `app/components/play/events/narration_component.rb`:

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

      def relative_time
        helpers.time_ago_in_words(event.occurred_at) + " ago"
      end
    end
  end
end
```

- [ ] **Step 4: Write the ERB template**

Create `app/components/play/events/narration_component.html.erb`:

```erb
<div class="py-3">
  <p class="text-slate-200 leading-relaxed"><%= text %></p>
  <p class="mt-1 text-xs text-slate-600"><%= relative_time %></p>
</div>
```

- [ ] **Step 5: Run the spec to verify it passes**

Run: `bundle exec rspec spec/components/play/events/narration_component_spec.rb`
Expected: 3 examples, 0 failures.

- [ ] **Step 6: Run the full suite**

Run: `bundle exec rspec`
Expected: green.

- [ ] **Step 7: Commit**

```bash
git add app/components/play/events/narration_component.rb app/components/play/events/narration_component.html.erb spec/components/play/events/narration_component_spec.rb
git commit -m "Add Play::Events::NarrationComponent (Phase 6.9)"
```

---

## Task 10: Play::Events::DiceRollComponent

Renders an inline card with dice expression, result, and optional breakdown.

**Files:**
- Create: `app/components/play/events/dice_roll_component.rb`
- Create: `app/components/play/events/dice_roll_component.html.erb`
- Create: `spec/components/play/events/dice_roll_component_spec.rb`

- [ ] **Step 1: Write the failing spec**

Create `spec/components/play/events/dice_roll_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Play::Events::DiceRollComponent, type: :component do
  let(:campaign) { create(:campaign) }
  let(:scene)    { create(:scene, campaign: campaign) }
  let(:event) do
    create(:event, :dice_roll,
           scene: scene,
           payload: { "expression" => "2d6+3", "result" => 10, "breakdown" => [ 4, 3, "+3" ] },
           occurred_at: 2.minutes.ago)
  end

  it "renders the dice expression" do
    render_inline(described_class.new(event: event))

    expect(page).to have_text("2d6+3")
  end

  it "renders the result" do
    render_inline(described_class.new(event: event))

    expect(page).to have_text("10")
  end

  it "renders the breakdown when present" do
    render_inline(described_class.new(event: event))

    expect(page).to have_text(/4.*3.*\+3/)
  end

  it "omits the breakdown line when absent" do
    event_no_breakdown = create(:event,
                                scene: scene,
                                kind: "dice_roll",
                                payload: { "expression" => "1d20", "result" => 15 })
    render_inline(described_class.new(event: event_no_breakdown))

    expect(page).to have_text("1d20")
    expect(page).to have_text("15")
  end

  describe "asymmetry" do
    let(:faction) { create(:faction, campaign: campaign) }
    let(:npc)     { create(:npc, campaign: campaign) }

    before do
      create(:faction_secret, faction: faction, label: "hidden temple", content: "in the swamp")
      create(:npc_secret,     npc: npc,         label: "true identity", content: "is a doppelganger")
    end

    it "does not leak secrets of related records" do
      rendered = render_inline(described_class.new(event: event)).to_s
      expect(rendered).not_to leak_secrets_of(faction, npc)
    end
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/components/play/events/dice_roll_component_spec.rb`
Expected: failure with `NameError: uninitialized constant Play::Events::DiceRollComponent`.

- [ ] **Step 3: Write the component class**

Create `app/components/play/events/dice_roll_component.rb`:

```ruby
module Play
  module Events
    class DiceRollComponent < ViewComponent::Base
      def initialize(event:)
        @event = event
      end

      attr_reader :event

      def expression
        event.payload["expression"].to_s
      end

      def result
        event.payload["result"]
      end

      def breakdown
        event.payload["breakdown"]
      end

      def breakdown?
        breakdown.is_a?(Array) && breakdown.any?
      end

      def relative_time
        helpers.time_ago_in_words(event.occurred_at) + " ago"
      end
    end
  end
end
```

- [ ] **Step 4: Write the ERB template**

Create `app/components/play/events/dice_roll_component.html.erb`:

```erb
<div class="my-3 rounded-r border-l-4 border-amber-500 bg-slate-800 px-3 py-2">
  <p class="text-xs uppercase tracking-widest text-amber-400"><%= expression %></p>
  <p class="text-lg font-semibold text-slate-100">Result: <%= result %></p>
  <% if breakdown? %>
    <p class="text-xs text-slate-400">
      <%= breakdown.join(" ") %>
    </p>
  <% end %>
  <p class="mt-1 text-xs text-slate-600"><%= relative_time %></p>
</div>
```

- [ ] **Step 5: Run the spec to verify it passes**

Run: `bundle exec rspec spec/components/play/events/dice_roll_component_spec.rb`
Expected: 5 examples, 0 failures.

- [ ] **Step 6: Run the full suite**

Run: `bundle exec rspec`
Expected: green.

- [ ] **Step 7: Commit**

```bash
git add app/components/play/events/dice_roll_component.rb app/components/play/events/dice_roll_component.html.erb spec/components/play/events/dice_roll_component_spec.rb
git commit -m "Add Play::Events::DiceRollComponent (Phase 6.10)"
```

---

## Task 11: Play::Events::OracleQueryComponent

Renders an inline card with the question, answer, and optional likelihood/chaos labels.

**Files:**
- Create: `app/components/play/events/oracle_query_component.rb`
- Create: `app/components/play/events/oracle_query_component.html.erb`
- Create: `spec/components/play/events/oracle_query_component_spec.rb`

- [ ] **Step 1: Write the failing spec**

Create `spec/components/play/events/oracle_query_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Play::Events::OracleQueryComponent, type: :component do
  let(:campaign) { create(:campaign) }
  let(:scene)    { create(:scene, campaign: campaign) }
  let(:event) do
    create(:event, :oracle_query,
           scene: scene,
           payload: {
             "question"   => "Is it raining?",
             "likelihood" => "even_odds",
             "chaos"      => 5,
             "answer"     => "yes"
           },
           occurred_at: 1.minute.ago)
  end

  it "renders the question" do
    render_inline(described_class.new(event: event))

    expect(page).to have_text("Is it raining?")
  end

  it "renders the answer" do
    render_inline(described_class.new(event: event))

    expect(page).to have_text("yes")
  end

  it "renders the likelihood and chaos labels" do
    render_inline(described_class.new(event: event))

    expect(page).to have_text(/even.odds/i)
    expect(page).to have_text(/chaos.*5/i)
  end

  describe "asymmetry" do
    let(:faction) { create(:faction, campaign: campaign) }
    let(:npc)     { create(:npc, campaign: campaign) }

    before do
      create(:faction_secret, faction: faction, label: "hidden temple", content: "in the swamp")
      create(:npc_secret,     npc: npc,         label: "true identity", content: "is a doppelganger")
    end

    it "does not leak secrets of related records" do
      rendered = render_inline(described_class.new(event: event)).to_s
      expect(rendered).not_to leak_secrets_of(faction, npc)
    end
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/components/play/events/oracle_query_component_spec.rb`
Expected: failure with `NameError: uninitialized constant Play::Events::OracleQueryComponent`.

- [ ] **Step 3: Write the component class**

Create `app/components/play/events/oracle_query_component.rb`:

```ruby
module Play
  module Events
    class OracleQueryComponent < ViewComponent::Base
      def initialize(event:)
        @event = event
      end

      attr_reader :event

      def question
        event.payload["question"].to_s
      end

      def answer
        event.payload["answer"].to_s
      end

      def likelihood
        event.payload["likelihood"].to_s
      end

      def chaos
        event.payload["chaos"]
      end

      def relative_time
        helpers.time_ago_in_words(event.occurred_at) + " ago"
      end
    end
  end
end
```

- [ ] **Step 4: Write the ERB template**

Create `app/components/play/events/oracle_query_component.html.erb`:

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
  <p class="mt-1 text-xs text-slate-600"><%= relative_time %></p>
</div>
```

- [ ] **Step 5: Run the spec to verify it passes**

Run: `bundle exec rspec spec/components/play/events/oracle_query_component_spec.rb`
Expected: 4 examples, 0 failures.

- [ ] **Step 6: Run the full suite**

Run: `bundle exec rspec`
Expected: green.

- [ ] **Step 7: Commit**

```bash
git add app/components/play/events/oracle_query_component.rb app/components/play/events/oracle_query_component.html.erb spec/components/play/events/oracle_query_component_spec.rb
git commit -m "Add Play::Events::OracleQueryComponent (Phase 6.11)"
```

---

## Task 12: Play::Events::SceneTransitionComponent

Renders a subtle dashed divider with a transition reason.

**Files:**
- Create: `app/components/play/events/scene_transition_component.rb`
- Create: `app/components/play/events/scene_transition_component.html.erb`
- Create: `spec/components/play/events/scene_transition_component_spec.rb`

- [ ] **Step 1: Write the failing spec**

Create `spec/components/play/events/scene_transition_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Play::Events::SceneTransitionComponent, type: :component do
  let(:campaign) { create(:campaign) }
  let(:scene)    { create(:scene, campaign: campaign) }
  let(:event) do
    create(:event, :scene_transition,
           scene: scene,
           payload: { "reason" => "Player chose to leave the tavern." },
           occurred_at: 30.seconds.ago)
  end

  it "renders the transition reason" do
    render_inline(described_class.new(event: event))

    expect(page).to have_text("Player chose to leave the tavern.")
  end

  it "renders a relative timestamp" do
    render_inline(described_class.new(event: event))

    expect(page).to have_text(/ago/)
  end

  describe "asymmetry" do
    let(:faction) { create(:faction, campaign: campaign) }
    let(:npc)     { create(:npc, campaign: campaign) }

    before do
      create(:faction_secret, faction: faction, label: "hidden temple", content: "in the swamp")
      create(:npc_secret,     npc: npc,         label: "true identity", content: "is a doppelganger")
    end

    it "does not leak secrets of related records" do
      rendered = render_inline(described_class.new(event: event)).to_s
      expect(rendered).not_to leak_secrets_of(faction, npc)
    end
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/components/play/events/scene_transition_component_spec.rb`
Expected: failure with `NameError: uninitialized constant Play::Events::SceneTransitionComponent`.

- [ ] **Step 3: Write the component class**

Create `app/components/play/events/scene_transition_component.rb`:

```ruby
module Play
  module Events
    class SceneTransitionComponent < ViewComponent::Base
      def initialize(event:)
        @event = event
      end

      attr_reader :event

      def reason
        event.payload["reason"].to_s
      end

      def relative_time
        helpers.time_ago_in_words(event.occurred_at) + " ago"
      end
    end
  end
end
```

- [ ] **Step 4: Write the ERB template**

Create `app/components/play/events/scene_transition_component.html.erb`:

```erb
<div class="my-6 border-t border-dashed border-slate-700 pt-3 text-center">
  <p class="text-xs uppercase tracking-widest text-slate-500"><%= reason %></p>
  <p class="mt-1 text-xs text-slate-600"><%= relative_time %></p>
</div>
```

- [ ] **Step 5: Run the spec to verify it passes**

Run: `bundle exec rspec spec/components/play/events/scene_transition_component_spec.rb`
Expected: 3 examples, 0 failures.

- [ ] **Step 6: Run the full suite**

Run: `bundle exec rspec`
Expected: green.

- [ ] **Step 7: Commit**

```bash
git add app/components/play/events/scene_transition_component.rb app/components/play/events/scene_transition_component.html.erb spec/components/play/events/scene_transition_component_spec.rb
git commit -m "Add Play::Events::SceneTransitionComponent (Phase 6.12)"
```

---

## Task 13: Play::Events::Component dispatcher

A module (not a class) with a frozen REGISTRY hash and a `.for(event)` class method.

**Files:**
- Create: `app/components/play/events/component.rb`
- Create: `spec/components/play/events/component_spec.rb`

- [ ] **Step 1: Write the failing spec**

Create `spec/components/play/events/component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Play::Events::Component do
  let(:campaign) { create(:campaign) }
  let(:scene)    { create(:scene, campaign: campaign) }

  describe ".for(event)" do
    it "returns NarrationComponent for kind=narration" do
      event = build(:event, scene: scene, kind: "narration")
      expect(described_class.for(event)).to eq(Play::Events::NarrationComponent)
    end

    it "returns DiceRollComponent for kind=dice_roll" do
      event = build(:event, scene: scene, kind: "dice_roll")
      expect(described_class.for(event)).to eq(Play::Events::DiceRollComponent)
    end

    it "returns OracleQueryComponent for kind=oracle_query" do
      event = build(:event, scene: scene, kind: "oracle_query")
      expect(described_class.for(event)).to eq(Play::Events::OracleQueryComponent)
    end

    it "returns SceneTransitionComponent for kind=scene_transition" do
      event = build(:event, scene: scene, kind: "scene_transition")
      expect(described_class.for(event)).to eq(Play::Events::SceneTransitionComponent)
    end

    it "raises ArgumentError for an unknown kind" do
      # We can't build an Event with an unknown kind through the enum, so
      # stub the kind reader directly to simulate the failure path.
      event = build(:event, scene: scene, kind: "narration")
      allow(event).to receive(:kind).and_return("not_a_real_kind")

      expect { described_class.for(event) }.to raise_error(ArgumentError, /no component registered/)
    end
  end

  describe "REGISTRY" do
    it "is frozen" do
      expect(described_class::REGISTRY).to be_frozen
    end

    it "covers all four event kinds" do
      expect(described_class::REGISTRY.keys).to contain_exactly(
        "narration", "dice_roll", "oracle_query", "scene_transition"
      )
    end
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/components/play/events/component_spec.rb`
Expected: failure with `NameError: uninitialized constant Play::Events::Component`.

- [ ] **Step 3: Write the dispatcher module**

Create `app/components/play/events/component.rb`:

```ruby
module Play
  module Events
    module Component
      REGISTRY = {
        "narration"        => NarrationComponent,
        "dice_roll"        => DiceRollComponent,
        "oracle_query"     => OracleQueryComponent,
        "scene_transition" => SceneTransitionComponent
      }.freeze

      def self.for(event)
        REGISTRY.fetch(event.kind) do
          raise ArgumentError, "no component registered for event kind #{event.kind.inspect}"
        end
      end
    end
  end
end
```

- [ ] **Step 4: Run the spec to verify it passes**

Run: `bundle exec rspec spec/components/play/events/component_spec.rb`
Expected: 7 examples, 0 failures.

- [ ] **Step 5: Run the full suite**

Run: `bundle exec rspec`
Expected: green.

- [ ] **Step 6: Commit**

```bash
git add app/components/play/events/component.rb spec/components/play/events/component_spec.rb
git commit -m "Add Play::Events::Component dispatcher (Phase 6.13)"
```

---

## Task 14: Play::Scenes::LogComponent

Renders events in chronological order via the dispatcher, with a text-only empty state when there are no events.

**Files:**
- Create: `app/components/play/scenes/log_component.rb`
- Create: `app/components/play/scenes/log_component.html.erb`
- Create: `spec/components/play/scenes/log_component_spec.rb`

- [ ] **Step 1: Write the failing spec**

Create `spec/components/play/scenes/log_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Play::Scenes::LogComponent, type: :component do
  let(:campaign) { create(:campaign) }
  let(:scene)    { create(:scene, campaign: campaign) }

  describe "with no events" do
    it "renders a text-only empty state" do
      render_inline(described_class.new(scene: scene))

      expect(page).to have_text(/the scene is set/i)
    end
  end

  describe "with events of multiple kinds" do
    let!(:narration_event) do
      create(:event,
             scene: scene,
             kind: "narration",
             payload: { "text" => "The tavern is quiet." },
             occurred_at: 5.minutes.ago)
    end
    let!(:dice_event) do
      create(:event, :dice_roll,
             scene: scene,
             payload: { "expression" => "2d6+3", "result" => 10 },
             occurred_at: 4.minutes.ago)
    end
    let!(:oracle_event) do
      create(:event, :oracle_query,
             scene: scene,
             payload: { "question" => "Does he leave?", "answer" => "no" },
             occurred_at: 3.minutes.ago)
    end

    it "renders each event via its dedicated component" do
      render_inline(described_class.new(scene: scene))

      expect(page).to have_text("The tavern is quiet.")
      expect(page).to have_text("2d6+3")
      expect(page).to have_text("Does he leave?")
    end

    it "renders events in chronological order (oldest to newest)" do
      rendered = render_inline(described_class.new(scene: scene)).to_s

      narration_pos = rendered.index("The tavern is quiet.")
      dice_pos      = rendered.index("2d6+3")
      oracle_pos    = rendered.index("Does he leave?")

      expect(narration_pos).to be < dice_pos
      expect(dice_pos).to be < oracle_pos
    end
  end

  describe "asymmetry" do
    let(:faction) { create(:faction, campaign: campaign) }
    let(:npc)     { create(:npc, campaign: campaign) }

    before do
      create(:event, scene: scene, kind: "narration", payload: { "text" => "Innocuous text." })
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

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/components/play/scenes/log_component_spec.rb`
Expected: failure with `NameError: uninitialized constant Play::Scenes::LogComponent`.

- [ ] **Step 3: Write the component class**

Create `app/components/play/scenes/log_component.rb`:

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
        events.empty?
      end

      def component_for(event)
        Play::Events::Component.for(event).new(event: event)
      end
    end
  end
end
```

- [ ] **Step 4: Write the ERB template**

Create `app/components/play/scenes/log_component.html.erb`:

```erb
<div class="space-y-1">
  <% if empty? %>
    <p class="py-8 text-center text-sm text-slate-500">
      The scene is set, but nothing has happened yet.
    </p>
  <% else %>
    <% events.each do |event| %>
      <%= render component_for(event) %>
    <% end %>
  <% end %>
</div>
```

- [ ] **Step 5: Run the spec to verify it passes**

Run: `bundle exec rspec spec/components/play/scenes/log_component_spec.rb`
Expected: 4 examples, 0 failures.

- [ ] **Step 6: Run the full suite**

Run: `bundle exec rspec`
Expected: green.

- [ ] **Step 7: Commit**

```bash
git add app/components/play/scenes/log_component.rb app/components/play/scenes/log_component.html.erb spec/components/play/scenes/log_component_spec.rb
git commit -m "Add Play::Scenes::LogComponent (Phase 6.14)"
```

---

## Task 15: Play::Scenes::PlayComponent

The page-level wrapper: campaign + scene header, log, and the reserved-but-empty right-pane slot.

**Files:**
- Create: `app/components/play/scenes/play_component.rb`
- Create: `app/components/play/scenes/play_component.html.erb`
- Create: `spec/components/play/scenes/play_component_spec.rb`

- [ ] **Step 1: Write the failing spec**

Create `spec/components/play/scenes/play_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Play::Scenes::PlayComponent, type: :component do
  let(:campaign) { create(:campaign, name: "Curse of Strahd") }
  let(:scene)    { create(:scene, campaign: campaign, title: "Tavern at Dusk", summary: "Rainy.") }

  it "renders the campaign name as a small header" do
    render_inline(described_class.new(scene: scene))

    expect(page).to have_text("Curse of Strahd")
  end

  it "renders the scene title as a large header" do
    render_inline(described_class.new(scene: scene))

    expect(page).to have_text("Tavern at Dusk")
  end

  it "renders the scene summary if present" do
    render_inline(described_class.new(scene: scene))

    expect(page).to have_text("Rainy.")
  end

  it "renders the log component (empty state for a fresh scene)" do
    render_inline(described_class.new(scene: scene))

    expect(page).to have_text(/the scene is set/i)
  end

  it "renders a back link to the campaign play page" do
    render_inline(described_class.new(scene: scene))

    expect(page).to have_link(/back/i, href: play_campaign_path(campaign))
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

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/components/play/scenes/play_component_spec.rb`
Expected: failure with `NameError: uninitialized constant Play::Scenes::PlayComponent`.

- [ ] **Step 3: Write the component class**

Create `app/components/play/scenes/play_component.rb`:

```ruby
module Play
  module Scenes
    class PlayComponent < ViewComponent::Base
      def initialize(scene:)
        @scene = scene
      end

      attr_reader :scene

      def campaign
        scene.campaign
      end
    end
  end
end
```

- [ ] **Step 4: Write the ERB template**

Create `app/components/play/scenes/play_component.html.erb`:

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

    <%# Reserved structural space for the Phase 9+ right-pane tabs
        (character sheet, scene images, narrator-side faction sidebar).
        Empty in Phase 6. %>
  </div>
</div>
```

- [ ] **Step 5: Run the spec to verify it passes**

Run: `bundle exec rspec spec/components/play/scenes/play_component_spec.rb`
Expected: 6 examples, 0 failures.

- [ ] **Step 6: Run the full suite**

Run: `bundle exec rspec`
Expected: green.

- [ ] **Step 7: Commit**

```bash
git add app/components/play/scenes/play_component.rb app/components/play/scenes/play_component.html.erb spec/components/play/scenes/play_component_spec.rb
git commit -m "Add Play::Scenes::PlayComponent (Phase 6.15)"
```

---

## Task 16: Play::ScenesController#play

The controller that renders the scene play surface.

**Files:**
- Create: `app/controllers/play/scenes_controller.rb`
- Create: `spec/requests/play/scenes_spec.rb`

- [ ] **Step 1: Write the failing spec**

Create `spec/requests/play/scenes_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Play::Scenes", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:campaign) { create(:campaign, user: user) }
  let(:scene) { create(:scene, campaign: campaign, title: "Tavern at Dusk") }

  describe "GET /campaigns/:campaign_id/scenes/:id/play" do
    context "unauthenticated" do
      it "redirects to sign-in" do
        get "/campaigns/#{campaign.id}/scenes/#{scene.id}/play"

        expect(response).to have_http_status(:found)
        expect(response.location).to include("/users/sign_in")
      end
    end

    context "authenticated" do
      before { sign_in user }

      it "renders the scene play page" do
        get "/campaigns/#{campaign.id}/scenes/#{scene.id}/play"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Tavern at Dusk")
        expect(response.body).to match(/the scene is set/i)
      end

      it "404s for a scene in another user's campaign" do
        other_campaign = create(:campaign, user: other_user)
        other_scene    = create(:scene, campaign: other_campaign)

        expect {
          get "/campaigns/#{other_campaign.id}/scenes/#{other_scene.id}/play"
        }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "404s when the scene exists but does not belong to the campaign in the URL" do
        # Two campaigns under the same user; scene belongs to campaign A, URL uses campaign B.
        campaign_b = create(:campaign, user: user)

        expect {
          get "/campaigns/#{campaign_b.id}/scenes/#{scene.id}/play"
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/requests/play/scenes_spec.rb`
Expected: failure on the authenticated case (controller doesn't exist).

- [ ] **Step 3: Write the controller**

Create `app/controllers/play/scenes_controller.rb`:

```ruby
module Play
  class ScenesController < ::ApplicationController
    def play
      @scene = current_user
                 .campaigns
                 .find(params[:campaign_id])
                 .scenes
                 .find(params[:id])

      render Play::Scenes::PlayComponent.new(scene: @scene)
    end
  end
end
```

- [ ] **Step 4: Run the spec to verify it passes**

Run: `bundle exec rspec spec/requests/play/scenes_spec.rb`
Expected: 4 examples, 0 failures.

- [ ] **Step 5: Run the full suite**

Run: `bundle exec rspec`
Expected: green.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/play/scenes_controller.rb spec/requests/play/scenes_spec.rb
git commit -m "Add Play::ScenesController#play (Phase 6.16)"
```

---

## Task 17: Lookbook previews

Eight preview classes covering each new component. Previews use `Event.new` / `Scene.new` — no DB writes.

**Files:**
- Create: `spec/components/previews/play/events/narration_component_preview.rb`
- Create: `spec/components/previews/play/events/dice_roll_component_preview.rb`
- Create: `spec/components/previews/play/events/oracle_query_component_preview.rb`
- Create: `spec/components/previews/play/events/scene_transition_component_preview.rb`
- Create: `spec/components/previews/play/scenes/log_component_preview.rb`
- Create: `spec/components/previews/play/campaigns/scene_picker_component_preview.rb`
- Create: `spec/components/previews/admin/scenes/row_component_preview.rb`
- Create: `spec/components/previews/admin/scenes/form_component_preview.rb`

- [ ] **Step 1: Create the NarrationComponent preview**

Create `spec/components/previews/play/events/narration_component_preview.rb`:

```ruby
module Play
  module Events
    class NarrationComponentPreview < ViewComponent::Preview
      def default
        event = Event.new(
          kind: "narration",
          payload: { "text" => "The tavern is quiet. Rain drips from the eaves outside." },
          occurred_at: Time.current
        )
        render Play::Events::NarrationComponent.new(event: event)
      end

      def long_text
        event = Event.new(
          kind: "narration",
          payload: { "text" => ("A long paragraph of narration filling the scene with detail. " * 8) },
          occurred_at: Time.current
        )
        render Play::Events::NarrationComponent.new(event: event)
      end
    end
  end
end
```

- [ ] **Step 2: Create the DiceRollComponent preview**

Create `spec/components/previews/play/events/dice_roll_component_preview.rb`:

```ruby
module Play
  module Events
    class DiceRollComponentPreview < ViewComponent::Preview
      def default
        event = Event.new(
          kind: "dice_roll",
          payload: { "expression" => "1d20", "result" => 15 },
          occurred_at: Time.current
        )
        render Play::Events::DiceRollComponent.new(event: event)
      end

      def with_breakdown
        event = Event.new(
          kind: "dice_roll",
          payload: { "expression" => "2d6+3", "result" => 10, "breakdown" => [ 4, 3, "+3" ] },
          occurred_at: Time.current
        )
        render Play::Events::DiceRollComponent.new(event: event)
      end

      def negative_result
        event = Event.new(
          kind: "dice_roll",
          payload: { "expression" => "1d20-2", "result" => -1, "breakdown" => [ 1, "-2" ] },
          occurred_at: Time.current
        )
        render Play::Events::DiceRollComponent.new(event: event)
      end
    end
  end
end
```

- [ ] **Step 3: Create the OracleQueryComponent preview**

Create `spec/components/previews/play/events/oracle_query_component_preview.rb`:

```ruby
module Play
  module Events
    class OracleQueryComponentPreview < ViewComponent::Preview
      def default
        event = Event.new(
          kind: "oracle_query",
          payload: {
            "question"   => "Is it raining?",
            "likelihood" => "even_odds",
            "chaos"      => 5,
            "answer"     => "yes"
          },
          occurred_at: Time.current
        )
        render Play::Events::OracleQueryComponent.new(event: event)
      end

      def exceptional_yes
        event = Event.new(
          kind: "oracle_query",
          payload: {
            "question"   => "Does the stranger reveal himself?",
            "likelihood" => "unlikely",
            "chaos"      => 7,
            "answer"     => "exceptional yes"
          },
          occurred_at: Time.current
        )
        render Play::Events::OracleQueryComponent.new(event: event)
      end

      def exceptional_no
        event = Event.new(
          kind: "oracle_query",
          payload: {
            "question"   => "Does the door open?",
            "likelihood" => "even_odds",
            "chaos"      => 3,
            "answer"     => "exceptional no"
          },
          occurred_at: Time.current
        )
        render Play::Events::OracleQueryComponent.new(event: event)
      end
    end
  end
end
```

- [ ] **Step 4: Create the SceneTransitionComponent preview**

Create `spec/components/previews/play/events/scene_transition_component_preview.rb`:

```ruby
module Play
  module Events
    class SceneTransitionComponentPreview < ViewComponent::Preview
      def default
        event = Event.new(
          kind: "scene_transition",
          payload: { "reason" => "Player chose to leave the tavern." },
          occurred_at: Time.current
        )
        render Play::Events::SceneTransitionComponent.new(event: event)
      end
    end
  end
end
```

- [ ] **Step 5: Create the LogComponent preview**

Create `spec/components/previews/play/scenes/log_component_preview.rb`:

```ruby
module Play
  module Scenes
    class LogComponentPreview < ViewComponent::Preview
      def with_one_of_each_kind
        scene = build_scene_with_events(
          [
            { kind: "narration",        payload: { "text" => "The tavern is quiet. Rain drips from the eaves." } },
            { kind: "dice_roll",        payload: { "expression" => "2d6+3", "result" => 10, "breakdown" => [ 4, 3, "+3" ] } },
            { kind: "narration",        payload: { "text" => "You notice a familiar dagger on his belt." } },
            { kind: "oracle_query",     payload: { "question" => "Does he leave?", "likelihood" => "unlikely", "chaos" => 5, "answer" => "no, exceptional" } },
            { kind: "scene_transition", payload: { "reason" => "Player followed the stranger to the forest." } }
          ]
        )
        render Play::Scenes::LogComponent.new(scene: scene)
      end

      def empty
        # Build an unsaved Scene with no events so the empty state renders.
        scene = Scene.new(title: "Empty scene", summary: nil)
        scene.define_singleton_method(:events) { Event.none }
        render Play::Scenes::LogComponent.new(scene: scene)
      end

      private

      def build_scene_with_events(event_specs)
        # In-memory scene + in-memory events for visual review without DB writes.
        scene = Scene.new(title: "Preview scene")
        events = event_specs.map.with_index do |spec, i|
          Event.new(
            scene: scene,
            kind: spec[:kind],
            payload: spec[:payload],
            occurred_at: Time.current - (event_specs.size - i).minutes
          )
        end
        scene.define_singleton_method(:events) do
          Class.new do
            def initialize(records) = @records = records
            def order(*) = self
            def empty? = @records.empty?
            def each(&block) = @records.each(&block)
            def to_a = @records.to_a
            include Enumerable
          end.new(events)
        end
        scene
      end
    end
  end
end
```

- [ ] **Step 6: Create the ScenePickerComponent preview**

Create `spec/components/previews/play/campaigns/scene_picker_component_preview.rb`:

```ruby
module Play
  module Campaigns
    class ScenePickerComponentPreview < ViewComponent::Preview
      def default
        campaign = Campaign.new(id: 1, name: "Curse of Strahd")
        scenes = [
          Scene.new(id: 1, campaign: campaign, title: "Tavern at Dusk", summary: "Rainy, quiet.", position: 1),
          Scene.new(id: 2, campaign: campaign, title: "The Forest Path", summary: "Misty, cold.", position: 2),
          Scene.new(id: 3, campaign: campaign, title: "Castle Ravenloft", summary: "Empty halls.", position: 3)
        ]
        campaign.define_singleton_method(:scenes) do
          Class.new do
            def initialize(records) = @records = records
            def order(*) = @records
          end.new(scenes)
        end
        render Play::Campaigns::ScenePickerComponent.new(campaign: campaign)
      end

      def single_scene
        campaign = Campaign.new(id: 1, name: "One-shot")
        scenes = [
          Scene.new(id: 1, campaign: campaign, title: "The Only Scene", summary: "All the action.", position: 1)
        ]
        campaign.define_singleton_method(:scenes) do
          Class.new do
            def initialize(records) = @records = records
            def order(*) = @records
          end.new(scenes)
        end
        render Play::Campaigns::ScenePickerComponent.new(campaign: campaign)
      end
    end
  end
end
```

- [ ] **Step 7: Create the Admin::Scenes::RowComponent preview**

Create `spec/components/previews/admin/scenes/row_component_preview.rb`:

```ruby
module Admin
  module Scenes
    class RowComponentPreview < ViewComponent::Preview
      def default
        campaign = Campaign.new(id: 1)
        scene = Scene.new(id: 2, campaign: campaign, title: "Middle scene", summary: "A scene in the middle.", position: 2)
        scene.define_singleton_method(:first?) { false }
        scene.define_singleton_method(:last?) { false }
        render(Admin::Scenes::RowComponent.new(scene: scene), layout: false)
      end

      def first_position
        campaign = Campaign.new(id: 1)
        scene = Scene.new(id: 1, campaign: campaign, title: "First scene", summary: "Cannot move up.", position: 1)
        scene.define_singleton_method(:first?) { true }
        scene.define_singleton_method(:last?) { false }
        render(Admin::Scenes::RowComponent.new(scene: scene), layout: false)
      end

      def last_position
        campaign = Campaign.new(id: 1)
        scene = Scene.new(id: 3, campaign: campaign, title: "Last scene", summary: "Cannot move down.", position: 3)
        scene.define_singleton_method(:first?) { false }
        scene.define_singleton_method(:last?) { true }
        render(Admin::Scenes::RowComponent.new(scene: scene), layout: false)
      end
    end
  end
end
```

- [ ] **Step 8: Create the Admin::Scenes::FormComponent preview**

Create `spec/components/previews/admin/scenes/form_component_preview.rb`:

```ruby
module Admin
  module Scenes
    class FormComponentPreview < ViewComponent::Preview
      def new_scene
        campaign = Campaign.new(id: 1)
        scene = Scene.new(campaign: campaign)
        render Admin::Scenes::FormComponent.new(campaign: campaign, scene: scene)
      end

      def editing_scene
        campaign = Campaign.new(id: 1)
        scene = Scene.new(id: 2, campaign: campaign, title: "Existing scene", summary: "Has a summary.")
        scene.define_singleton_method(:persisted?) { true }
        render Admin::Scenes::FormComponent.new(campaign: campaign, scene: scene)
      end

      def with_errors
        campaign = Campaign.new(id: 1)
        scene = Scene.new(campaign: campaign, title: "")
        scene.valid?
        render Admin::Scenes::FormComponent.new(campaign: campaign, scene: scene)
      end
    end
  end
end
```

- [ ] **Step 9: Verify the previews load**

Start the Rails server in development:

```bash
bin/rails server
```

In another shell, fetch the Lookbook index to verify it loads without 500s:

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/lookbook
```

Expected: `200`.

Stop the server with `Ctrl-C`.

This is a smoke check, not a CI test. Lookbook previews are dev-side affordances and don't run in the CI test suite.

- [ ] **Step 10: Run the full suite to verify nothing regressed**

Run: `bundle exec rspec`
Expected: green.

- [ ] **Step 11: Commit**

```bash
git add spec/components/previews
git commit -m "Add Lookbook previews for Phase 6 components (Phase 6.17)"
```

---

## Task 18: End-to-end system spec

One Capybara walk-through proving the full Phase 6 user flow.

**Files:**
- Create: `spec/system/phase_6_play_surface_spec.rb`

- [ ] **Step 1: Write the system spec**

Create `spec/system/phase_6_play_surface_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Phase 6 play surface (end-to-end)", type: :system do
  before { driven_by :rack_test }

  let(:password) { "correct horse battery staple" }
  let!(:user) { create(:user, password: password, password_confirmation: password) }
  let!(:campaign) { create(:campaign, user: user, name: "Curse of Strahd") }

  it "lets a user create a scene in admin and then play it" do
    # Sign in on apex.
    Capybara.app_host = "http://gygaxagain.com"
    visit "/users/sign_in"
    fill_in "Email", with: user.email
    fill_in "Password", with: password
    click_button "Log in"

    # With one campaign already created, the user gets redirected to the play
    # subdomain's scene picker — which shows the placeholder because no scenes
    # exist yet.
    expect(current_url).to include("gygaxagain.com/campaigns/#{campaign.id}/play")
    expect(page).to have_text(/no scenes yet/i)

    # Navigate to admin to create a scene.
    Capybara.app_host = "http://admin.gygaxagain.com"
    visit "/campaigns"
    click_link "Curse of Strahd"

    # Now on the campaign show page.
    expect(current_url).to include("admin.gygaxagain.com/campaigns/#{campaign.id}")
    expect(page).to have_text("Curse of Strahd")
    expect(page).to have_text(/no scenes yet/i)

    # Create a scene.
    click_link "New scene"
    fill_in "Title", with: "Tavern at Dusk"
    fill_in "Summary", with: "Rainy, quiet."
    click_button "Create scene"

    # Redirected back to the campaign show page; sees the new scene.
    expect(current_url).to include("admin.gygaxagain.com/campaigns/#{campaign.id}")
    expect(page).to have_text("Tavern at Dusk")
    expect(page).to have_text("Rainy, quiet.")

    # Switch to the play subdomain. The scene picker should now show the scene.
    Capybara.app_host = "http://gygaxagain.com"
    visit "/campaigns/#{campaign.id}/play"

    expect(page).to have_text("Choose a scene")
    expect(page).to have_link("Tavern at Dusk")

    # Click into the scene.
    click_link "Tavern at Dusk"

    # On the scene play page; sees the empty-log state.
    expect(current_url).to match(%r{gygaxagain\.com/campaigns/#{campaign.id}/scenes/\d+/play})
    expect(page).to have_text("Tavern at Dusk")
    expect(page).to have_text(/the scene is set/i)
  end
end
```

- [ ] **Step 2: Run the system spec**

Run: `bundle exec rspec spec/system/phase_6_play_surface_spec.rb`
Expected: 1 example, 0 failures.

If the after-sign-in redirect lands on the admin new-campaign form instead of the play scene picker, the `last_played_campaign_id` redirect logic isn't firing the way Phase 3 wired it. Verify by checking the existing system spec at `spec/system/campaign_authoring_spec.rb` — Phase 3's redirect logic should pick the last-played campaign first. If our user has `last_played_campaign_id` nil (never played), the existing logic routes to the admin new-campaign flow. Adjust the spec's pre-conditions: the `let!(:campaign)` setup gives the user a campaign but doesn't set `last_played_campaign_id`. To force the user into the play picker on sign-in, also pre-create a `:scene` so the after-sign-in logic considers them a "playing user." If Phase 3's logic specifically requires `last_played_campaign_id` to be set, instead pre-set `user.last_played_campaign_id = campaign.id` in the `let!`.

Adjust the test setup as needed to match Phase 3's exact redirect contract; the existing `spec/system/campaign_authoring_spec.rb` is the reference.

- [ ] **Step 3: Run the full suite**

Run: `bundle exec rspec`
Expected: green.

- [ ] **Step 4: Commit**

```bash
git add spec/system/phase_6_play_surface_spec.rb
git commit -m "Add Phase 6 end-to-end system spec (Phase 6.18)"
```

---

## Task 19: Final pass — RuboCop, erb_lint, acceptance check

Polish + verification.

- [ ] **Step 1: Run RuboCop**

Run: `bundle exec rubocop`
Expected: 0 offenses. If style issues fire (typically bracket spacing or string quoting), apply autocorrects:

```bash
bundle exec rubocop -A
```

Re-run `bundle exec rubocop` to verify clean.

- [ ] **Step 2: Run erb_lint**

Run: `bundle exec erb_lint --lint-all`
Expected: 0 offenses. If lint issues fire, apply autocorrects:

```bash
bundle exec erb_lint --lint-all -a
```

Re-run to verify clean.

- [ ] **Step 3: Run the full test suite**

Run: `bundle exec rspec`
Expected: all tests pass. Roughly count: ~30 new specs added across Phase 6 tasks. Total should be ~285+ examples.

- [ ] **Step 4: Verify the Lookbook smoke check (manual)**

Start the dev server:

```bash
bin/rails server
```

Visit `http://localhost:3000/lookbook` in a browser. Verify:
- Each Phase 6 preview class appears in the sidebar.
- Each preview example renders without an error page.
- The visual treatments (narration body text, dice roll amber accent, oracle violet accent, scene transition dashed divider) look reasonable.

Stop the server.

- [ ] **Step 5: Acceptance criteria walkthrough**

Verify each acceptance criterion from issue #7:

- [ ] `https://gygaxagain.com/campaigns/:id/scenes/:scene_id/play` renders the scene log via `Play::SceneLogComponent` (implemented as `Play::Scenes::LogComponent` per the spec's naming clarification). Check: `spec/requests/play/scenes_spec.rb` and `spec/components/play/scenes/log_component_spec.rb` green.
- [ ] Each Event kind has a corresponding `Play::Events::*Component`. Check: four component files exist under `app/components/play/events/`, each with a spec.
- [ ] A polymorphic dispatcher (`Play::Events::Component.for(event)`) routes each event to its component. Check: `app/components/play/events/component.rb` exists; `spec/components/play/events/component_spec.rb` covers all four kinds + the error path.
- [ ] Admin can create/edit/delete scenes from `admin.gygaxagain.com/campaigns/:id/scenes`. Check: `Admin::ScenesController` exists with full CRUD; `spec/requests/admin/scenes_spec.rb` covers all actions.
- [ ] Lookbook previews exist for each Event component. Check: four preview files exist under `spec/components/previews/play/events/`; the Lookbook smoke check (Step 4) verifies they render.

- [ ] **Step 6: Commit any final autocorrects (if there were any)**

```bash
git add -A
git status
```

If there are RuboCop or erb_lint autocorrect changes pending, commit them:

```bash
git commit -m "Phase 6 final pass: RuboCop + erb_lint autocorrects (Phase 6.19)"
```

If `git status` shows nothing to commit (lints were already clean), skip this step.

- [ ] **Step 7: Final sanity check**

Run:

```bash
git status
git log --oneline -25
bundle exec rspec
```

Expected: clean working tree (or only the unrelated Phase-6-prep changes in `app/javascript/`, `app/views/layouts/`, etc. that existed at the start of Phase 5 — those may still be uncommitted); 18 or 19 Phase 6 commits in the log; green test suite.

Phase 6 is complete.
