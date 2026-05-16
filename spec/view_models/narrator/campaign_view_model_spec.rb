require "rails_helper"

RSpec.describe Narrator::CampaignViewModel, type: :view_model do
  let(:campaign) { create(:campaign, name: "Phandalin", description: "Hook text.") }

  before do
    create(:player_character, campaign:, name: "Aragorn",  role: "pc",        notes: "main")
    create(:player_character, campaign:, name: "Caine",    role: "companion", notes: nil)
    create(:faction, campaign:)
    create(:npc, campaign:)
  end

  it "exposes name, description, factions, npcs, and pcs/companions split by role" do
    vm = described_class.new(campaign)
    expect(vm.name).to eq("Phandalin")
    expect(vm.description).to eq("Hook text.")
    expect(vm.factions).to all(be_a(Narrator::FactionViewModel))
    expect(vm.npcs).to all(be_a(Narrator::NpcViewModel))
    expect(vm.pcs.map(&:name)).to eq([ "Aragorn" ])
    expect(vm.companions.map(&:name)).to eq([ "Caine" ])
  end

  it "exposes main_character when set" do
    aragorn = campaign.player_characters.find_by(name: "Aragorn")
    campaign.update!(main_character: aragorn)
    expect(described_class.new(campaign).main_character.name).to eq("Aragorn")
  end

  it "returns nil main_character when unset" do
    expect(described_class.new(campaign).main_character).to be_nil
  end
end
