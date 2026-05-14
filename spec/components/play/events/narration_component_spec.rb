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
