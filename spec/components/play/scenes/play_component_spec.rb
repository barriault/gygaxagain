require "rails_helper"

RSpec.describe Play::Scenes::PlayComponent, type: :component do
  include Rails.application.routes.url_helpers

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

    expect(page).to have_link("← Back to #{campaign.name}", href: play_campaign_path(campaign))
  end

  it "renders the input dock (dice + oracle forms)" do
    render_inline(described_class.new(scene: scene))

    expect(page).to have_text(/roll dice/i)
    expect(page).to have_text(/ask the oracle/i)
  end

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
