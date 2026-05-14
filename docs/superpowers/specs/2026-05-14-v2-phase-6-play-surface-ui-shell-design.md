# v2 Phase 6 — Play surface UI shell

Date: 2026-05-14
Status: Design spec. Drives the writing-plans pass for Phase 6.
Issue: [#7](https://github.com/barriault/gygaxagain/issues/7)
Parent roadmap: [`2026-05-13-v2-phase-0-roadmap-design.md`](2026-05-13-v2-phase-0-roadmap-design.md)
Prior phase: [`2026-05-14-v2-phase-5-asymmetry-schema-and-viewmodels-design.md`](2026-05-14-v2-phase-5-asymmetry-schema-and-viewmodels-design.md)

## Scope

The chat-like play surface UI and the admin affordances needed to author what gets played. On the play side: a per-campaign scene picker (`/campaigns/:id/play`), a per-scene log (`/campaigns/:id/scenes/:scene_id/play`), and four per-event-kind components (`Play::Events::NarrationComponent`, `DiceRollComponent`, `OracleQueryComponent`, `SceneTransitionComponent`) wired together by an explicit-registry dispatcher (`Play::Events::Component.for(event)`). On the admin side: a campaign show page that lists scenes, plus full scene CRUD with up/down reorder buttons backed by `acts_as_list`. Lookbook previews for every new ViewComponent. Empty scene logs render an empty-state. No LLM, no dice service, no oracle service, no player input area — pure UI shell.

## Dependencies

Phase 5 ([#6](https://github.com/barriault/gygaxagain/issues/6)) complete: `Scene`, `Event`, and the four event kinds (`narration`, `dice_roll`, `oracle_query`, `scene_transition`) exist; `Faction`/`FactionSecret` and `Npc`/`NpcSecret` exist for asymmetry-test seeding; the `leak_secrets_of` matcher exists and accepts String subjects. Phase 3's `Admin::CampaignsController` exists with `index`, `new`, `create`, `edit`, `update`, `destroy` (no `show` yet); Phase 3's `Play::CampaignsController#index` and `#play` exist. Phase 5.16's `ApplicationViewModel` inheritance fix and the `leak_secrets_of` vacuous-pass guard are in place.

## Acceptance criteria

Verbatim from the GitHub issue:

- `https://gygaxagain.com/campaigns/:id/scenes/:scene_id/play` renders the scene log via `Play::SceneLogComponent`.
- Each Event kind has a corresponding `Play::Events::*Component` (NarrationComponent, DiceRollComponent, OracleQueryComponent, SceneTransitionComponent).
- A polymorphic dispatcher (`Play::Events::Component.for(event)`) routes each event to its component.
- Admin can create/edit/delete scenes from `admin.gygaxagain.com/campaigns/:id/scenes`.
- Lookbook previews exist for each Event component.

(Naming clarification: the issue's `Play::SceneLogComponent` is implemented as `Play::Scenes::LogComponent` to match the project's nested-namespace pattern (`Play::Campaigns::PickerComponent`, `Admin::Campaigns::FormComponent`). The acceptance criterion is satisfied — the component renders the log at the specified URL — under the codebase-consistent name.)

## Architectural commitments inherited from Phase 0

Phase 0 already locks the relevant ViewComponent + Hotwire decisions. This spec applies them; it does not re-litigate them.

- **ViewComponent for all view composition.** No partials in the new code path. Every render goes through a component.
- **MVVC pattern with explicit ViewModels.** Phase 5 established that ViewModels exist for asymmetric models (Faction, Npc) and are NOT required for non-asymmetric models. Phase 6 introduces no new ViewModels; Scene and Event are non-asymmetric and have no `*_secrets` companion.
- **Hotwire (Turbo + Stimulus).** Phase 6 uses neither Turbo Streams nor new Stimulus controllers. The page renders server-side once and is static thereafter. Phase 7's dice button and Phase 8's streaming narration both bring Turbo Streams in.
- **Subdomain split.** Play and admin remain isolated namespaces. The play surface never imports admin components, and vice versa. Phase 6's "navigate from admin scene CRUD to play surface" only happens via the user clicking a link — there's no cross-namespace component reuse.
- **Default-deny auth on `ApplicationController`.** Phase 6 adds new controllers under `Play::` and `Admin::`, all inheriting `before_action :authenticate_user!` from the application base. No new skips.
- **Tenant scoping through `current_user.campaigns.find`.** Every controller action that touches a campaign-scoped record loads it through `current_user.campaigns.find(params[:campaign_id]).scenes.find(params[:id])` (or equivalent). Cross-user access returns 404 (not 403).
- **Asymmetry test surface extends to components.** Every player-facing component spec asserts `not_to leak_secrets_of(faction, npc)` against a rendered component output. The matcher already supports String subjects from Phase 5.10; no matcher changes needed.

## Open decisions resolved in this spec

### Scene/Event ViewModels: not introduced

**Decision:** Phase 6 does NOT add `Player::SceneViewModel` or `Player::EventViewModel`. ViewComponents receive `Scene` and `Event` ActiveRecord objects directly.

Rationale: ViewModels in this codebase exist for asymmetry enforcement (a `Player::FactionViewModel` cannot reach a `FactionSecret`). Scene and Event have no `*_secrets` companion — there is nothing for a ViewModel to hide. Adding ViewModels for them would be ceremony without payoff.

If a future phase introduces typed payload helpers (`Event::Narration.new(event).text`), they go in `app/models/events/` as plain Ruby classes, not under `app/view_models/`. Phase 6 does not need them.

### Polymorphic dispatcher: explicit registry hash

**Decision:** `Play::Events::Component` is a module (not a class) with a frozen `REGISTRY` hash and a class method `.for(event)` that does `REGISTRY.fetch(event.kind)`.

```ruby
module Play
  module Events
    module Component
      REGISTRY = {
        "narration"        => NarrationComponent,
        "dice_roll"        => DiceRollComponent,
        "oracle_query"     => OracleQueryComponent,
        "scene_transition" => SceneTransitionComponent,
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

Alternatives considered:

- Convention via `const_get("#{event.kind.camelize}Component")` — clever but breaks on acronyms and edge-case kinds; runtime `NameError`s are worse than explicit registry-misses.
- Each component declares its handled kind via a `HANDLES` constant — most ceremony, still needs a registration list to scan.

The explicit registry is one line per kind, fails loudly on misses, and is easy to grep.

### Scene log layout: inline chat-like (single column)

**Decision:** `Play::Scenes::LogComponent` renders events in a single chronological column, latest at the bottom. Narration is body text. Dice rolls and oracle queries are inline cards with kind-distinguishing left-border accent colors. Scene transitions are subtle dashed dividers.

Alternatives considered:

- Two-column (story left, mechanics right) — splits chronological cause-and-effect across columns.
- Timeline/log style (every event a timestamped row) — uniform but reads like an audit trail rather than a story.

The inline-chat style is closest to the issue's "chat-like" phrasing and matches the mental model of a play-by-post game.

**Future direction (out of scope for Phase 6):** the play page will grow a right-pane tabbed interface (character sheet, scene images). Phase 6 reserves the structural space in `Play::Scenes::PlayComponent` — leaving it empty for now — so adding tabs later doesn't require restructuring.

### Play-side scene entry: scene picker

**Decision:** `Play::CampaignsController#play` action (existing) picks between two components based on whether the campaign has scenes:

- Zero scenes → `Play::Campaigns::PlaceholderComponent` (retargeted as the zero-scenes empty state: "No scenes yet. Create one in admin.").
- One or more scenes → `Play::Campaigns::ScenePickerComponent` (new: list of scenes ordered by `:position`, each linking to its play URL).

Alternatives considered:

- Auto-redirect to the most-recently-created scene — requires a `last_played_scene_id` schema addition Phase 6 doesn't need, and still needs a fallback for zero-scenes.
- One-component empty-state-plus-list — conflates two distinct visual states.

The two-component split keeps each state visually clean and gives Lookbook previews a sharper subject.

### Admin campaign navigation to scenes: campaign show page

**Decision:** Phase 3's `Admin::CampaignsController` adds a `show` action. `Admin::Campaigns::ShowComponent` renders the campaign metadata at top and a scenes list (ordered by `:position`) inline. Each campaign row in `Admin::Campaigns::IndexComponent` becomes a link to its show page.

Phase 3's spec anticipated this: "When Phase 5 adds associated rows worth surfacing, the show action returns." Phase 5 didn't (bare schema); Phase 6 does (scenes are renderable, manageable content per campaign).

The `Admin::ScenesController#index` action redirects to the campaign show page rather than rendering a separate scenes-only index. Single navigation path; no duplicate UI.

### Scene reordering: up/down buttons

**Decision:** Admin scene rows include "↑" and "↓" buttons that POST to `move_up` / `move_down` member actions, which call `acts_as_list`'s `move_higher!` / `move_lower!` on the scene and redirect back to the campaign show page with a flash.

Alternative considered:

- Drag-drop via Sortable.js + a Stimulus controller — nicer UX but requires JS infrastructure not in Phase 6's scope.

Buttons match the `acts_as_list` API directly and are accessible without JS.

### Lookbook preview directory: `spec/components/previews/`

**Decision:** Preview classes live at `spec/components/previews/`, mirroring the component namespace tree. Each preview class has a `Preview` suffix.

```
spec/components/previews/play/events/narration_component_preview.rb
spec/components/previews/play/events/dice_roll_component_preview.rb
spec/components/previews/play/events/oracle_query_component_preview.rb
spec/components/previews/play/events/scene_transition_component_preview.rb
spec/components/previews/play/scenes/log_component_preview.rb
spec/components/previews/play/campaigns/scene_picker_component_preview.rb
spec/components/previews/admin/scenes/row_component_preview.rb
spec/components/previews/admin/scenes/form_component_preview.rb
```

`config/application.rb` adds the preview path:

```ruby
config.view_component.preview_paths << Rails.root.join("spec/components/previews").to_s
```

Each Event component preview has at least two examples: `default` (representative) and one variant (long text, edge values, etc.). The `LogComponent` preview shows a scene with one of each event kind.

Previews use `Event.new` and `Scene.new` (no `.save`) — no dev DB pollution. Previews are NOT executed in CI; the component specs are the actual test coverage.

### Admin scene `index` action: redirect to campaign show

**Decision:** `Admin::ScenesController#index` is defined (so `index` paths like `admin_campaign_scenes_path` resolve) but its action body is `redirect_to admin_campaign_path(@campaign)`. No separate scenes-only index page. The campaign show page IS the scenes index.

### Empty scene log: text-only empty state

**Decision:** When `scene.events.empty?`, `Play::Scenes::LogComponent` renders a subtle text-only empty state ("The scene is set, but nothing has happened yet.") instead of an empty container. No artwork, no illustrated empty state.

### Event timestamps in the log: subtle, relative

**Decision:** Each event row in the log shows a small relative timestamp ("just now", "3 minutes ago") using Rails' `time_ago_in_words` helper, rendered with subdued styling. Polish call subject to revision in Lookbook review.

### Stimulus controllers: none new in Phase 6

**Decision:** Phase 6 introduces no new Stimulus controllers. The existing `flash_controller.js` (from the working-tree Phase-6-prep changes) is reused for flash dismissal across new admin pages. Auto-scroll-to-bottom for streaming arrives in Phase 8.

### Strong params

**Decision:**

- Scene: `params.require(:scene).permit(:title, :summary)`. No `campaign_id` (URL-inferred), no `position` (acts_as_list-managed).

## File inventory

Every file added or modified in Phase 6, grouped by area. Canonical list for the implementation plan.

### Routes

`config/routes/play.rb` — modified:

```ruby
constraints subdomain: "" do
  devise_for :users, skip: [:registrations], controllers: { sessions: "users/sessions" }
  root "play/home#show"

  scope module: "play" do
    resources :campaigns, only: [:index] do
      member { get :play }
      resources :scenes, only: [] do
        member { get :play }
      end
    end
  end
end
```

`config/routes/admin.rb` — modified:

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
      resource :llm, only: [:show, :create], controller: "llm"
    end
  end
end
```

Note: `except: [:show]` is removed from `resources :campaigns` (Phase 3 had it; Phase 6 needs `show`).

### Configuration

`config/application.rb` — modified to add the Lookbook preview path:

```ruby
config.view_component.preview_paths << Rails.root.join("spec/components/previews").to_s
```

(Verify the line isn't already present; if it is, no change.)

### Controllers

`app/controllers/play/campaigns_controller.rb` — modified:

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

      if @campaign.scenes.any?
        render Play::Campaigns::ScenePickerComponent.new(campaign: @campaign)
      else
        render Play::Campaigns::PlaceholderComponent.new(campaign: @campaign)
      end
    end
  end
end
```

`app/controllers/play/scenes_controller.rb` — new:

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

`app/controllers/admin/campaigns_controller.rb` — modified to add `show`:

```ruby
def show
  @campaign = current_user.campaigns.find(params[:id])
  render Admin::Campaigns::ShowComponent.new(campaign: @campaign)
end
```

`app/controllers/admin/scenes_controller.rb` — new (full CRUD + move actions). Inherits from `Admin::ApplicationController` (introduced in Phase 4) to pick up the admin layout:

```ruby
module Admin
  class ScenesController < Admin::ApplicationController
    before_action :load_campaign
    before_action :load_scene, only: [:edit, :update, :destroy, :move_up, :move_down]

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
               status: :unprocessable_content
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
               status: :unprocessable_content
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

### Play-side components

`app/components/play/campaigns/scene_picker_component.{rb,html.erb}` — new. Receives a `campaign:`. Renders a header ("Choose a scene"), a vertical list of `campaign.scenes.order(:position)` with title + truncated summary, each linking to `play_campaign_scene_path(campaign, scene)`.

`app/components/play/campaigns/placeholder_component.{rb,html.erb}` — modified. Retargeted as the zero-scenes empty state: "No scenes yet. Create one in admin." Drop the "Phase 6 placeholder" copy.

`app/components/play/scenes/play_component.{rb,html.erb}` — new. Page-level wrapper. Receives a `scene:`. Renders:
- A header band: campaign name (small) + scene title (large) + back link to scene picker.
- The scene's `summary` if present (subdued, below the title).
- The `LogComponent` rendering the events.
- A reserved-but-empty region where the future right-pane tabs will live (a div with a comment indicating Phase 9+).

`app/components/play/scenes/log_component.{rb,html.erb}` — new. Receives a `scene:`. Renders events in order (`scene.events.order(:occurred_at)`), each through `Play::Events::Component.for(event).new(event: event)`. If no events, renders the text-only empty state.

`app/components/play/events/component.rb` — new module (the dispatcher; see "Open decisions resolved in this spec").

`app/components/play/events/narration_component.{rb,html.erb}` — new. Receives `event:`. Renders `event.payload["text"]` as body text plus a small relative timestamp.

`app/components/play/events/dice_roll_component.{rb,html.erb}` — new. Receives `event:`. Renders an inline card with a small label (`event.payload["expression"]`), the result (`event.payload["result"]`), optional breakdown (`event.payload["breakdown"]` if present), and a timestamp.

`app/components/play/events/oracle_query_component.{rb,html.erb}` — new. Receives `event:`. Renders an inline card with the question (`event.payload["question"]`), the answer (`event.payload["answer"]`), and a small label showing `likelihood` and `chaos` if present, plus a timestamp.

`app/components/play/events/scene_transition_component.{rb,html.erb}` — new. Receives `event:`. Renders a subtle dashed divider with the transition reason (`event.payload["reason"]`) and a timestamp.

### Admin-side components

`app/components/admin/campaigns/show_component.{rb,html.erb}` — new. Receives `campaign:`. Renders the campaign metadata at top (name, description) plus a scenes section: a header with a "New scene" button, then the campaign's scenes ordered by `:position` rendered through `Admin::Scenes::RowComponent`. If no scenes, an empty state with the "New scene" CTA centered.

`app/components/admin/campaigns/index_component.html.erb` — modified. Each campaign row's name becomes a link to `admin_campaign_path(campaign)` (the new show page).

`app/components/admin/scenes/form_component.{rb,html.erb}` — new. Receives `campaign:`, `scene:`. Renders a form with `title` (required) and `summary` (textarea) fields. Posts to `admin_campaign_scenes_path(campaign)` for new, `admin_campaign_scene_path(campaign, scene)` for edit. Validation errors render inline next to fields. Submits to create/update via standard Rails form helpers.

`app/components/admin/scenes/row_component.{rb,html.erb}` — new. Receives `scene:`. Renders the scene title, truncated summary, up/down buttons (disabled at the boundaries: up disabled if `scene.first?`, down disabled if `scene.last?`), edit link, delete button (with Turbo confirm).

### Specs

**Component specs** (~13 files under `spec/components/play/` and `spec/components/admin/`):

- `spec/components/play/campaigns/scene_picker_component_spec.rb` — renders scene list; asymmetry test.
- `spec/components/play/campaigns/placeholder_component_spec.rb` — modified for the new empty-state copy; asymmetry test.
- `spec/components/play/scenes/play_component_spec.rb` — renders header + log; asymmetry test.
- `spec/components/play/scenes/log_component_spec.rb` — renders events in order, handles empty state, dispatches each event to the right component; asymmetry test.
- `spec/components/play/events/component_spec.rb` — registry round-trips each kind, unknown kind raises `ArgumentError`.
- `spec/components/play/events/narration_component_spec.rb` — renders text, timestamp; asymmetry test.
- `spec/components/play/events/dice_roll_component_spec.rb` — renders expression/result/breakdown; asymmetry test.
- `spec/components/play/events/oracle_query_component_spec.rb` — renders question/answer; asymmetry test.
- `spec/components/play/events/scene_transition_component_spec.rb` — renders divider with reason; asymmetry test.
- `spec/components/admin/campaigns/show_component_spec.rb` — renders campaign + scene list; renders empty state when no scenes.
- `spec/components/admin/scenes/form_component_spec.rb` — renders form fields; renders inline errors on invalid scene.
- `spec/components/admin/scenes/row_component_spec.rb` — renders title + summary + buttons; up disabled at first, down disabled at last.

**Request specs** (~4 files under `spec/requests/`):

- `spec/requests/play/scenes_spec.rb` — `GET /campaigns/:id/scenes/:id/play` happy path; 404 on cross-user; 404 on cross-campaign.
- `spec/requests/play/campaigns_spec.rb` — modified: assert scene picker renders when scenes exist, placeholder renders when none.
- `spec/requests/admin/campaigns_spec.rb` — modified: `GET /campaigns/:id` (show) renders; existing CRUD specs still pass.
- `spec/requests/admin/scenes_spec.rb` — new: full CRUD coverage + move_up/move_down redirects + position changes; 404 on cross-user.

**System spec** (one file):

- `spec/system/phase_6_play_surface_spec.rb` — sign in → admin creates a campaign → click into campaign → create a scene → click "Play" subdomain → land on campaign play (scene picker shows the scene) → click scene → land on scene log (empty state). Capybara + rack_test driver (no Selenium; no JS-driven UI in Phase 6).

**Lookbook previews** (8 files under `spec/components/previews/`):

- `play/events/narration_component_preview.rb` — `default` + `long_text`.
- `play/events/dice_roll_component_preview.rb` — `default` + `with_breakdown` + `negative_result`.
- `play/events/oracle_query_component_preview.rb` — `default` + `exceptional_yes` + `exceptional_no`.
- `play/events/scene_transition_component_preview.rb` — `default`.
- `play/scenes/log_component_preview.rb` — `with_one_of_each_kind`, `empty`.
- `play/campaigns/scene_picker_component_preview.rb` — `default` (3 scenes), `single_scene`.
- `admin/scenes/row_component_preview.rb` — `default`, `first_position` (up disabled), `last_position` (down disabled).
- `admin/scenes/form_component_preview.rb` — `new_scene`, `editing_scene`, `with_errors`.

## Asymmetry test pattern

Every `Play::*` component spec includes one asymmetry example:

```ruby
describe "asymmetry" do
  let(:campaign) { create(:campaign) }
  let(:scene)    { create(:scene, campaign: campaign) }
  let(:faction)  { create(:faction, campaign: campaign) }
  let(:npc)      { create(:npc, campaign: campaign) }

  before do
    create(:faction_secret, faction: faction, label: "hidden temple", content: "in the swamp")
    create(:npc_secret,     npc: npc,         label: "true identity", content: "is a doppelganger")
  end

  it "does not leak secrets of related records" do
    rendered = render_inline(described_class.new(...)).to_s
    expect(rendered).not_to leak_secrets_of(faction, npc)
  end
end
```

This is a preventive guard, not a reactive test — Phase 6 components don't reach for `Faction`/`Npc` data at all. The guard catches future regressions (a sidebar that "just renders the campaign's NPCs real quick" would surface secrets through the AR graph). Eight Play components × one asymmetry example each → eight guards.

Admin components don't get the asymmetry test (admin is the narrator-side surface; allowed to surface secrets).

## Out of scope / non-goals

- **No LLM integration.** No streaming, no Anthropic calls, no narration generation. (Phase 8.)
- **No dice or oracle service objects.** Components render dice roll *records*, but no UI affordance creates them. (Phase 7.)
- **No player input area.** The Phase 6 scene log is read-only from the player. (Phase 8.)
- **No Turbo Streams.** Page renders server-side once. (Phase 7/8 introduce them.)
- **No new Stimulus controllers.** The existing `flash_controller.js` is reused; nothing new. (Phase 8.)
- **No drag-drop scene reordering.** Up/down buttons only.
- **No bulk operations.** No "delete all scenes," no "duplicate scene."
- **No scene status/state field.** No "active" / "completed" / "archived" enum on Scene.
- **No right-pane (character sheet, images, etc.).** Reserved structurally; empty in Phase 6.
- **No Lookbook previews tested in CI.** Previews are dev-side affordances.
- **No admin event CRUD.** Events come from factories (test) and Phase 7+ service objects (dev/prod).
- **No per-user "last played scene."** Scene picker shows the full list every time.
- **No `Player::SceneViewModel` or `Player::EventViewModel`.** Scene and Event are non-asymmetric; ViewModels would be ceremony.
- **No payload reader classes (`Event::Narration`, etc.).** Components read `event.payload[...]` inline. If Phase 7+ service objects need shared payload knowledge, reader classes get introduced then.

## Future direction (captured for context, not implemented)

- **Two-column play surface.** `Play::Scenes::PlayComponent`'s right-pane slot will hold tabs: character sheet, scene images, narrator-side faction sidebar. Phase 6 reserves the slot structurally so Phase 9+ can add tabs without restructuring.
- **Streaming narration into the log.** Phase 8 will broadcast Turbo Streams that append tokens to a partially-rendered `NarrationComponent`. The component should not assume the full text is present at render time; Phase 8 can extend the same component without rewriting it.
- **Auto-scroll behavior.** With streaming events, the scene log will need an auto-scroll-to-bottom-on-new-event Stimulus controller. Phase 8 work.
- **Event timestamps visibility.** Phase 6 ships with subtle relative timestamps; Lookbook review may tune them down or up depending on play feel.

## Notes for the implementation plan

- The dispatcher module (`Play::Events::Component`) lives at `app/components/play/events/component.rb`. Rails 8's Zeitwerk autoload requires the constant name and file path to match — `Play::Events::Component` ↔ `app/components/play/events/component.rb`.
- The dispatcher REGISTRY references the four component classes by short name (e.g. `NarrationComponent`). When the dispatcher module loads, Ruby resolves those constants via Zeitwerk, which autoloads each component file on demand. No manual ordering is needed — implement the components and the dispatcher in any sequence; Zeitwerk handles the cascading loads at first use.
- `Play::Campaigns::PlaceholderComponent` already exists with placeholder copy from Phase 3. Phase 6 modifies it (not replaces it) — the existing spec assertions need updating.
- `Admin::Campaigns::IndexComponent` already exists and links each row's name to `edit_admin_campaign_path`. Phase 6 changes those links to point at `admin_campaign_path` (the new show page).
- `acts_as_list` defines `move_higher!` and `move_lower!` (with bang) and `move_higher` / `move_lower` (no bang). Both work; the plan uses the non-bang form because acts_as_list does not raise on already-at-boundary (it's a no-op), and the controller treats the action as idempotent.
- The system spec uses `Capybara.app_host` switching to simulate the apex / `admin` subdomain navigation across the test. Phase 2's spec helpers may already support this; otherwise the plan adds the switching helpers.
- Asymmetry tests on player components use the existing `leak_secrets_of` matcher unmodified.
