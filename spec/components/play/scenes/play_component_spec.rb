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

  describe "Phase 9.1 layout" do
    let(:scene) { create(:scene) }
    let!(:pc) { create(:player_character, campaign: scene.campaign, name: "Aragorn", role: "pc").tap { scene.campaign.update!(main_character: _1) } }

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
