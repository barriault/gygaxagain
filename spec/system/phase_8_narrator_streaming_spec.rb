require "rails_helper"

RSpec.describe "Phase 8 narrator streaming", type: :system, js: true do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let!(:campaign) { create(:campaign, user: user, name: "Test Run", description: "A short test campaign.") }
  let!(:scene) { create(:scene, campaign: campaign, title: "The Tavern", summary: "A noisy hall.") }

  before do
    # Switch ActionCable from the test adapter (queues in memory, never pushes
    # to WebSocket clients) to the async adapter (in-process pub/sub that
    # delivers to live WebSocket connections held by the Selenium browser).
    # Must happen before `visit` so the browser's WebSocket connects to the
    # async adapter.
    require "action_cable/subscription_adapter/async"
    ActionCable.server.restart
    ActionCable.server.config.cable = { "adapter" => "async" }

    allow(Rails.application.credentials).to receive(:dig).with(:anthropic, :api_key).and_return("sk-test")
    Llm::Providers::Anthropic.reset_client!
    stub_anthropic_streaming(text_chunks: [ "The bartender ", "looks up. ", "He waves you over." ],
                             input_tokens: 50, output_tokens: 12)
    Capybara.app_host = "http://lvh.me"
    sign_in user
  end

  after do
    ActionCable.server.restart
    ActionCable.server.config.cable = { "adapter" => "test" }
    Capybara.app_host = "http://gygaxagain.com"
  end

  it "submits a player action, streams the narration into the log, and finalizes" do
    visit play_campaign_scene_path(campaign, scene)

    # Wait for the ActionCable subscription (turbo-cable-stream-source) to be
    # established before submitting. Without this, the broadcast from
    # NarrationJob may fire before the browser has subscribed to the channel.
    # The element is intentionally hidden (no visible content), so visible: false is required.
    expect(page).to have_css("turbo-cable-stream-source[connected]", visible: false, wait: 5)

    fill_in "narration[text]", with: "I greet the bartender."
    click_button "Narrate"

    expect(page).to have_text("I greet the bartender.")

    perform_enqueued_jobs

    expect(page).to have_text("The bartender looks up. He waves you over.", wait: 10)
    expect(page).not_to have_css("[data-narration-status='streaming']")
  end
end
