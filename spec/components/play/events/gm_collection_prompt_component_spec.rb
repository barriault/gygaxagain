require "rails_helper"

RSpec.describe Play::Events::GmCollectionPromptComponent, type: :component do
  let(:campaign) { create(:campaign) }
  let(:scene)    { create(:scene, campaign:) }
  let(:event)    { create(:event, scene:, kind: "gm_collection_prompt", payload: { "text" => "And the others?" }) }

  it "renders the prompt text with DM voice tag" do
    rendered = render_inline(described_class.new(event: event))
    expect(rendered.to_s).to include("And the others?")
    expect(rendered.to_s).to include("DM")
  end

  describe "asymmetry" do
    before do
      faction = create(:faction, campaign:)
      create(:faction_secret, faction:, content: "hidden")
      npc = create(:npc, campaign:)
      create(:npc_secret, npc:, content: "hidden")
    end

    it "does not leak_secrets_of related records" do
      rendered = render_inline(described_class.new(event: event))
      expect(rendered.to_s).not_to leak_secrets_of(*Faction.all, *Npc.all)
    end
  end
end
