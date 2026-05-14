require "rails_helper"

RSpec.describe Narrator::NpcSecretViewModel, type: :view_model do
  let(:npc)    { create(:npc) }
  let(:secret) { create(:npc_secret, npc: npc, label: "true identity", content: "is a doppelganger") }
  let(:vm)     { described_class.new(secret) }

  describe "exposed attrs" do
    it { expect(described_class.exposed_attrs).to eq([ :id, :label, :content ]) }
  end

  describe "values" do
    it "returns id, label, and content" do
      expect(vm.id).to eq(secret.id)
      expect(vm.label).to eq("true identity")
      expect(vm.content).to eq("is a doppelganger")
    end
  end
end
