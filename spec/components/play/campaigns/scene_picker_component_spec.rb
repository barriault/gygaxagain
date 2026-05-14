require "rails_helper"

RSpec.describe Play::Campaigns::ScenePickerComponent, type: :component do
  include Rails.application.routes.url_helpers

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
