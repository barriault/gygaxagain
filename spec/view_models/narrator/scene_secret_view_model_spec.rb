require "rails_helper"

RSpec.describe Narrator::SceneSecretViewModel, type: :view_model do
  let(:secret) { create(:scene_secret, label: "Encounter map", content: "2 skeletons at the door") }

  it "exposes label and content" do
    vm = described_class.new(secret)
    expect(vm.to_h).to include(label: "Encounter map", content: "2 skeletons at the door")
  end
end
