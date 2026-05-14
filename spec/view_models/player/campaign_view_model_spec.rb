require "rails_helper"

RSpec.describe Player::CampaignViewModel do
  let(:campaign) { create(:campaign, name: "Faerûn", description: "A high-fantasy setting.") }
  subject(:vm)   { described_class.new(campaign) }

  describe "exposed attributes" do
    it "exposes id, name, description" do
      expect(described_class.exposed_attrs).to eq(%i[id name description])
    end

    it "returns model values" do
      expect(vm.name).to eq("Faerûn")
      expect(vm.description).to eq("A high-fantasy setting.")
      expect(vm.id).to eq(campaign.id)
    end
  end

  describe "asymmetry" do
    let!(:faction) { create(:faction, :with_secrets, campaign: campaign) }
    let!(:npc)     { create(:npc, :with_secrets, campaign: campaign) }

    it "does not leak any secret content" do
      expect(vm).not_to leak_secrets_of(faction, npc)
    end
  end
end
