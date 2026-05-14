require "rails_helper"

RSpec.describe Player::FactionViewModel, type: :view_model do
  let(:campaign) { create(:campaign) }
  let(:faction)  { create(:faction, campaign: campaign, name: "The Cult", public_description: "A shadowy group") }
  let(:vm)       { described_class.new(faction) }

  describe "exposed attrs" do
    it { expect(described_class.exposed_attrs).to eq([:id, :name, :public_description]) }
  end

  describe "values" do
    it "returns id, name, and public_description from the record" do
      expect(vm.id).to eq(faction.id)
      expect(vm.name).to eq("The Cult")
      expect(vm.public_description).to eq("A shadowy group")
    end
  end

  describe "structural asymmetry" do
    it "does not expose :secrets" do
      expect(described_class).not_to expose_attrs_via(:secrets)
    end

    it "does not respond to #secrets" do
      expect(vm).not_to respond_to(:secrets)
    end
  end

  describe "dynamic asymmetry (not_to_leak)" do
    before do
      create(:faction_secret, faction: faction, label: "hidden temple", content: "in the swamp")
      create(:faction_secret, faction: faction, label: "true leader",   content: "is the mayor")
    end

    it "does not leak secrets of the faction" do
      expect(vm).not_to leak_secrets_of(faction)
    end
  end
end
