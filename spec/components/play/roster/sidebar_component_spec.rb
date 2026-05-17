require "rails_helper"

RSpec.describe Play::Roster::SidebarComponent, type: :component do
  let(:scene)    { create(:scene) }
  let!(:aragorn) { create(:player_character, campaign: scene.campaign, name: "Aragorn", role: "pc").tap { scene.campaign.update!(main_character: _1) } }
  let!(:caine)   { create(:player_character, campaign: scene.campaign, name: "Caine", role: "companion") }

  it "renders PCs and Companions sections with names" do
    rendered = render_inline(described_class.new(scene: scene))
    expect(rendered.to_s).to include("PCs")
    expect(rendered.to_s).to include("Aragorn")
    expect(rendered.to_s).to include("Companions")
    expect(rendered.to_s).to include("Caine")
  end

  it "marks main PC with ★" do
    rendered = render_inline(described_class.new(scene: scene))
    expect(rendered.to_s).to include("★")
  end

  describe "asymmetry" do
    before do
      create(:faction_secret, faction: create(:faction, campaign: scene.campaign), content: "hidden")
      # Also test that PC notes don't leak — store sensitive notes
      aragorn.update!(notes: "SECRET DM NOTE")
    end

    it "does not leak secrets of related records (faction)" do
      rendered = render_inline(described_class.new(scene: scene))
      expect(rendered.to_s).not_to leak_secrets_of(*Faction.all)
    end

    it "does not leak PC notes (DM-only)" do
      rendered = render_inline(described_class.new(scene: scene))
      expect(rendered.to_s).not_to include("SECRET DM NOTE")
    end
  end
end
