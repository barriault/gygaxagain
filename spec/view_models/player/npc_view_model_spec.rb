require "rails_helper"

RSpec.describe Player::NpcViewModel, type: :view_model do
  let(:campaign) { create(:campaign) }
  let(:npc)      { create(:npc, campaign: campaign, name: "John", public_description: "A villager", location: "The town square") }
  let(:vm)       { described_class.new(npc) }

  describe "exposed attrs" do
    it { expect(described_class.exposed_attrs).to eq([:id, :name, :public_description, :location]) }
  end

  describe "values" do
    it "returns id, name, public_description, and location from the record" do
      expect(vm.id).to eq(npc.id)
      expect(vm.name).to eq("John")
      expect(vm.public_description).to eq("A villager")
      expect(vm.location).to eq("The town square")
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
      create(:npc_secret, npc: npc, label: "true identity", content: "is a doppelganger")
    end

    it "does not leak secrets of the npc" do
      expect(vm).not_to leak_secrets_of(npc)
    end
  end
end
