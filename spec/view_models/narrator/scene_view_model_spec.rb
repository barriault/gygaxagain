require "rails_helper"

RSpec.describe Narrator::SceneViewModel, type: :view_model do
  let(:scene) { create(:scene, title: "Cemetery", summary: "An old cemetery.") }

  before { create(:scene_secret, scene:, label: "Encounter", content: "2 skeletons") }

  it "exposes title, summary, and scene_secrets" do
    vm = described_class.new(scene)
    expect(vm.title).to eq("Cemetery")
    expect(vm.summary).to eq("An old cemetery.")
    expect(vm.scene_secrets).to all(be_a(Narrator::SceneSecretViewModel))
    expect(vm.to_h[:scene_secrets].first).to include(label: "Encounter", content: "2 skeletons")
  end
end
