require "rails_helper"

RSpec.describe Play::StateIndicatorComponent, type: :component do
  let(:scene)    { create(:scene) }
  let!(:aragorn) { create(:player_character, campaign: scene.campaign, name: "Aragorn", role: "pc").tap { scene.campaign.update!(main_character: _1) } }
  let!(:patric)  { create(:player_character, campaign: scene.campaign, name: "Patric",  role: "pc") }

  it "shows 'Waiting on:' with undeclared PCs during collecting phase" do
    # narration without '?' puts scene in collecting phase
    create(:event, scene:, kind: "narration", turn_number: 1, payload: { "text" => "The door opens." })
    create(:event, scene:, kind: "pc_declaration", pc: aragorn, turn_number: 1, payload: { "text" => "look" })
    rendered = render_inline(described_class.new(scene: scene))
    expect(rendered.to_s).to include("Waiting on")
    expect(rendered.to_s).to include("Patric")
  end

  it "renders nothing outside collecting phase" do
    # no events = :framing phase — render? returns false
    rendered = render_inline(described_class.new(scene: scene))
    expect(rendered.to_s.strip).to eq("")
  end

  describe "asymmetry" do
    before do
      create(:faction_secret, faction: create(:faction, campaign: scene.campaign), content: "hidden")
    end
    it "does not leak secrets of related records" do
      rendered = render_inline(described_class.new(scene: scene))
      expect(rendered.to_s).not_to leak_secrets_of(*Faction.all)
    end
  end
end
