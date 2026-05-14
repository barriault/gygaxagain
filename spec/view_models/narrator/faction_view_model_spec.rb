require "rails_helper"

RSpec.describe Narrator::FactionViewModel, type: :view_model do
  let(:campaign) { create(:campaign) }
  let(:faction)  { create(:faction, campaign: campaign, name: "The Cult", public_description: "A shadowy group") }
  let(:vm)       { described_class.new(faction) }

  before do
    create(:faction_secret, faction: faction, label: "hidden temple", content: "in the swamp")
    create(:faction_secret, faction: faction, label: "true leader",   content: "is the mayor")
  end

  describe "exposed attrs" do
    it "exposes the public set plus secrets" do
      expect(described_class.exposed_attrs).to eq([:id, :name, :public_description, :secrets])
    end
  end

  describe "values" do
    it "returns id, name, public_description from the record" do
      expect(vm.id).to eq(faction.id)
      expect(vm.name).to eq("The Cult")
      expect(vm.public_description).to eq("A shadowy group")
    end

    it "wraps secrets in Narrator::FactionSecretViewModel" do
      expect(vm.secrets).to all(be_a(Narrator::FactionSecretViewModel))
      expect(vm.secrets.map(&:label)).to contain_exactly("hidden temple", "true leader")
      expect(vm.secrets.map(&:content)).to contain_exactly("in the swamp", "is the mayor")
    end
  end

  describe "structural asymmetry (positive)" do
    it "is documented as exposing secrets" do
      expect(described_class).to expose_attrs_via(:secrets)
    end
  end

  describe "dynamic asymmetry (positive, symmetric matcher demonstration)" do
    it "DOES leak the secrets of its faction (by design — narrator-side)" do
      expect(vm).to leak_secrets_of(faction)
    end
  end
end
