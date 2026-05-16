require "rails_helper"

RSpec.describe Play::ComposerComponent, type: :component do
  let(:scene) { create(:scene) }
  let!(:pc)   { create(:player_character, campaign: scene.campaign, name: "Aragorn", role: "pc").tap { scene.campaign.update!(main_character: _1) } }

  it "renders a textarea for declarations" do
    # put scene in collecting phase — narration without '?' suffix and no open chip
    create(:event, scene:, kind: "narration", turn_number: 1, payload: { "text" => "The door opens." })
    rendered = render_inline(described_class.new(scene: scene))
    expect(rendered.to_s).to include("<textarea")
    expect(rendered.to_s).to include("Type your action")
  end

  it "disables the input when phase is awaiting_roll" do
    # closed chip [[expr]] triggers awaiting_roll in SceneStateViewModel
    create(:event, scene:, kind: "narration", turn_number: 1, payload: { "text" => "Roll [[1d20+3 — Aragorn Strength]]" })
    rendered = render_inline(described_class.new(scene: scene))
    expect(rendered.to_s).to include("disabled")
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
