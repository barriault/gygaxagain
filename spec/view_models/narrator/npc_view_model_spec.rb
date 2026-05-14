require "rails_helper"

RSpec.describe Narrator::NpcViewModel, type: :view_model do
  let(:campaign) { create(:campaign) }
  let(:npc)      { create(:npc, campaign: campaign, name: "John", public_description: "A villager", location: "The town square") }
  let(:vm)       { described_class.new(npc) }

  before do
    create(:npc_secret, npc: npc, label: "true identity", content: "is a doppelganger")
  end

  describe "exposed attrs" do
    it "exposes the public set plus secrets" do
      expect(described_class.exposed_attrs).to eq([:id, :name, :public_description, :location, :secrets])
    end
  end

  describe "values" do
    it "returns id, name, public_description, location from the record" do
      expect(vm.id).to eq(npc.id)
      expect(vm.name).to eq("John")
      expect(vm.public_description).to eq("A villager")
      expect(vm.location).to eq("The town square")
    end

    it "wraps secrets in Narrator::NpcSecretViewModel" do
      expect(vm.secrets).to all(be_a(Narrator::NpcSecretViewModel))
      expect(vm.secrets.map(&:label)).to eq(["true identity"])
      expect(vm.secrets.map(&:content)).to eq(["is a doppelganger"])
    end
  end

  describe "structural asymmetry (positive)" do
    it "is documented as exposing secrets" do
      expect(described_class).to expose_attrs_via(:secrets)
    end
  end

  describe "dynamic asymmetry (positive, symmetric matcher demonstration)" do
    it "DOES leak the secrets of its npc (by design — narrator-side)" do
      expect(vm).to leak_secrets_of(npc)
    end
  end
end
