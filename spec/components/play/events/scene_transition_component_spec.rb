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
