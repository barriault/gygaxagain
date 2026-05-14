require "rails_helper"

RSpec.describe Play::Scenes::InputDockComponent, type: :component do
  let(:user) { create(:user) }
  let(:campaign) { create(:campaign, user: user, chaos_factor: 5) }
  let(:scene)    { create(:scene, campaign: campaign) }

  it "renders the dice form" do
    render_inline(described_class.new(scene: scene))

    expect(page).to have_text(/roll dice/i)
    expect(page).to have_field("dice_roll[expression]")
  end

  it "renders the oracle form" do
    render_inline(described_class.new(scene: scene))

    expect(page).to have_text(/ask the oracle/i)
    expect(page).to have_field("oracle_query[question]")
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
