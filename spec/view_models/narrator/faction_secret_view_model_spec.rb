require "rails_helper"

RSpec.describe Narrator::FactionSecretViewModel, type: :view_model do
  let(:faction) { create(:faction) }
  let(:secret)  { create(:faction_secret, faction: faction, label: "hidden temple", content: "in the swamp") }
  let(:vm)      { described_class.new(secret) }

  describe "exposed attrs" do
    it { expect(described_class.exposed_attrs).to eq([ :id, :label, :content ]) }
  end

  describe "values" do
    it "returns id, label, and content" do
      expect(vm.id).to eq(secret.id)
      expect(vm.label).to eq("hidden temple")
      expect(vm.content).to eq("in the swamp")
    end
  end
end
