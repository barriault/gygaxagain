require "rails_helper"

RSpec.describe Play::Events::PcDeclarationComponent, type: :component do
  let(:campaign) { create(:campaign) }
  let(:pc)       { create(:player_character, campaign:, name: "Aragorn") }
  let(:scene)    { create(:scene, campaign:) }
  let(:event)    { create(:event, scene:, pc:, kind: "pc_declaration", payload: { "text" => "I look around." }) }

  it "renders the PC name and text" do
    rendered = render_inline(described_class.new(event: event))
    expect(rendered.to_s).to include("Aragorn")
    expect(rendered.to_s).to include("I look around.")
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
