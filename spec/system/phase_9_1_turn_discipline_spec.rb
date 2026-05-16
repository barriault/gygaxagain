require "rails_helper"

# Phase 9.1 — turn-discipline end-to-end system spec.
#
# Exercises the three-trigger pipeline through a real browser (headless Chrome)
# with a stubbed Anthropic API and async ActionCable:
#
#   framing (on page load)  →  collecting (after pc_declaration)  →  resolution (after "go")
#
# Architecture note:
#   NarrationJob uses broadcast_replace_to targeting each narration event's dom_id. This
#   works for events present in the initial page HTML (framing: created synchronously
#   during ScenesController#play, so included in the first render). For resolution
#   narration events created AFTER the initial page load (inside pc_declarations#create),
#   broadcast_replace on a non-existent element is a no-op in Turbo.
#
#   Resolution narration therefore appears when the page is next rendered (reload or
#   subsequent visit). These specs use page reload after declaration(s) as the
#   synchronization/assertion mechanism.
#
# Queue adapter:
#   :inline  — NarrationJob runs synchronously inside the controller action, ensuring
#   the narration text is committed to the DB (and broadcast attempted) before the spec
#   proceeds. No perform_enqueued_jobs calls needed.
RSpec.describe "Phase 9.1 turn discipline", type: :system, js: true do
  # Use inline adapter so NarrationJob runs synchronously inside the server
  # request thread. Eliminates job-queue timing races.
  around do |example|
    original = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :inline
    example.run
  ensure
    ActiveJob::Base.queue_adapter = original
  end

  let(:password) { "correct horse battery staple" }
  let(:user)     { create(:user, password: password, password_confirmation: password) }

  before do
    # Switch ActionCable from the test adapter (queues in memory, never pushes to
    # WebSocket clients) to the async adapter (in-process pub/sub that delivers
    # to live WebSocket connections held by the Selenium browser).
    # Must happen before `visit` so the browser's WebSocket connects to async.
    require "action_cable/subscription_adapter/async"
    ActionCable.server.restart
    ActionCable.server.config.cable = { "adapter" => "async" }

    allow(Rails.application.credentials).to receive(:dig).with(:anthropic, :api_key).and_return("sk-test")
    Llm::Providers::Anthropic.reset_client!

    Capybara.app_host = "http://lvh.me"
    sign_in user
  end

  after do
    ActionCable.server.restart
    ActionCable.server.config.cable = { "adapter" => "test" }
    Capybara.app_host = "http://gygaxagain.com"
  end

  # ---------------------------------------------------------------------------
  # Scenario 1: Solo PC (no companion)
  # framing → declaration → resolution (no companion check needed)
  # ---------------------------------------------------------------------------
  describe "solo PC: framing → declare → resolve" do
    let!(:campaign) { create(:campaign, user:, name: "Dungeon Run") }
    let!(:aragorn)  do
      create(:player_character, campaign:, name: "Aragorn", role: "pc").tap do |pc|
        campaign.update!(main_character: pc)
      end
    end
    let!(:scene) { create(:scene, campaign:, title: "The Dark Passage") }

    it "frames on load, then resolves after one declaration" do
      # With :inline adapter, NarrationJob runs synchronously inside ScenesController#play.
      # The framing narration is present in the initial page HTML (created before render).
      stub_anthropic_streaming(text_chunks: [ "You stand before a crumbling arch. ", "What does Aragorn do?" ])

      visit play_campaign_scene_path(campaign, scene)

      # Framing narration is in the initial HTML (inline job ran before page rendered).
      expect(page).to have_text("You stand before a crumbling arch.", wait: 5)
      expect(page).to have_text("What does Aragorn do?")

      # Phase is :idle (narration text ends with "?"), so state indicator doesn't render.
      expect(page).to have_no_css(".state-indicator", wait: 2)

      # Stub resolution narration. The job runs synchronously inside pc_declarations#create
      # via the :inline adapter.
      WebMock.reset!  # clear framing stub so resolution stub is unambiguous
      stub_anthropic_streaming(text_chunks: [ "Aragorn steps through the arch. ", "What does Aragorn do next?" ])

      # Player declares for Aragorn. No companion → advance_turn immediately enqueues
      # (and with :inline, runs) NarrationJob for resolution.
      fill_in "text", with: "I step through the arch."
      click_button "Send"

      # Resolution narration was created and the job ran synchronously. The broadcast_replace
      # fires but the resolution element was not in the initial DOM, so the browser doesn't
      # update in real-time. Reload to render all events from the DB.
      visit play_campaign_scene_path(campaign, scene)

      # Resolution narration now appears in the fresh page render.
      expect(page).to have_text("Aragorn steps through the arch.", wait: 5)
      expect(page).to have_text("What does Aragorn do next?")

      # Verify the pc_declaration event also appears in the log.
      expect(page).to have_text("I step through the arch.")
    end
  end

  # ---------------------------------------------------------------------------
  # Scenario 2: PC + companion
  # framing → declare → companion-check prompt → "they hold" → resolve
  # ---------------------------------------------------------------------------
  describe "PC + companion: framing → declare → companion check → resolve" do
    let!(:campaign) { create(:campaign, user:, name: "Fellowship") }
    let!(:aragorn)  do
      create(:player_character, campaign:, name: "Aragorn", role: "pc").tap do |pc|
        campaign.update!(main_character: pc)
      end
    end
    let!(:caine)  { create(:player_character, campaign:, name: "Caine",   role: "companion") }
    let!(:scene)  { create(:scene, campaign:, title: "The Hidden Ford") }

    it "frames, collects declaration, prompts companion check, then resolves on group shortcut" do
      stub_anthropic_streaming(text_chunks: [ "The river runs cold. ", "What does Aragorn do?" ])

      visit play_campaign_scene_path(campaign, scene)

      # Framing narration in initial HTML.
      expect(page).to have_text("The river runs cold.", wait: 5)
      expect(page).to have_text("What does Aragorn do?")

      # Player declares for Aragorn. With companion present, advance_turn creates a
      # companion_check gm_collection_prompt event — NOT a resolution narration.
      # No Anthropic call happens here; no stub needed for this step.
      fill_in "text", with: "I cross the river."
      click_button "Send"

      # Reload to see the gm_collection_prompt in the log.
      visit play_campaign_scene_path(campaign, scene)

      # The companion-check prompt is one of the three CollectionPrompt.companion_check templates:
      #   "Anything for Caine, or shall I run them?"
      #   "What about Caine?"
      #   "Anything from Caine?"
      expect(page).to have_text(/Anything (for|from) Caine|What about Caine/i, wait: 5)

      # Also verify the player's declaration is in the log.
      expect(page).to have_text("I cross the river.")

      # Stub resolution narration for the next step.
      WebMock.reset!
      stub_anthropic_streaming(text_chunks: [ "The party crosses the ford. ", "What does Aragorn do next?" ])

      # "they hold" matches GROUP_RE → Success for all undeclared companions (Caine) →
      # advance_turn with companion_prompt_offered? true → enqueue_resolution →
      # NarrationJob runs inline in the POST's server thread.
      fill_in "text", with: "they hold"
      click_button "Send"

      # Reload to see the resolution narration. The NarrationJob may still be running
      # inline in the POST thread when we arrive, so the narration might initially show
      # as streaming (status: "streaming"). We wait for the broadcast to finalize it,
      # or if that fails (broadcast is to the old Action Cable connection), we reload again.
      visit play_campaign_scene_path(campaign, scene)

      # If the inline NarrationJob hasn't committed yet (race condition with page reload),
      # the narration shows as streaming. Wait, then reload once more.
      if page.has_css?("[data-narration-status='streaming']", wait: 3)
        visit play_campaign_scene_path(campaign, scene)
      end

      # Resolution narration now appears.
      expect(page).to have_text("The party crosses the ford.", wait: 5)
      expect(page).to have_text("What does Aragorn do next?")
    end
  end
end
