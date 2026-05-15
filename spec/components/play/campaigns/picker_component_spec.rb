require "rails_helper"

RSpec.describe Play::Campaigns::PickerComponent, type: :component do
  it "renders one link per campaign" do
    user = create(:user)
    campaigns = [ create(:campaign, user: user, name: "Alpha"),
                 create(:campaign, user: user, name: "Beta") ]

    render_inline(described_class.new(campaigns: campaigns))

    expect(page).to have_link("Alpha")
    expect(page).to have_link("Beta")
  end

  it "renders an empty-state when given an empty collection" do
    render_inline(described_class.new(campaigns: Campaign.none))
    expect(page).to have_text(/no campaigns/i)
  end

  describe "asymmetry" do
    let(:user)     { create(:user) }
    let(:campaign) { create(:campaign, user: user) }
    let(:faction)  { create(:faction, campaign: campaign) }
    let(:npc)      { create(:npc,     campaign: campaign) }

    before do
      create(:faction_secret, faction: faction, label: "hidden temple", content: "in the swamp")
      create(:npc_secret,     npc: npc,         label: "true identity", content: "is a doppelganger")
    end

    it "does not leak secrets of related records" do
      rendered = render_inline(described_class.new(campaigns: [ campaign ])).to_s
      expect(rendered).not_to leak_secrets_of(faction, npc)
    end
  end
end
