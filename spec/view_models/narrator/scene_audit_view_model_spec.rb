require "rails_helper"

RSpec.describe Narrator::SceneAuditViewModel do
  let(:scene) { create(:scene, title: "T", summary: "S") }
  subject(:vm) { described_class.new(scene) }

  it "exposes id, title, summary, events" do
    expect(described_class.exposed_attrs).to eq(%i[id title summary events])
  end

  it "wraps events in Narrator::EventViewModel" do
    create(:event, scene: scene, kind: "narration", payload: { "text" => "x" })
    expect(vm.events).to all(be_a(Narrator::EventViewModel))
  end
end
