require "rails_helper"

RSpec.describe Narrator::EventViewModel do
  let(:scene) { create(:scene) }
  let(:event) { create(:event, scene: scene, kind: "narration", payload: { "text" => "ok" }) }

  it "exposes id, kind, occurred_at, text, occurred_at_label" do
    expect(described_class.exposed_attrs).to eq(%i[id kind occurred_at text occurred_at_label])
  end

  it "renders text per kind same as Player::EventViewModel" do
    expect(described_class.new(event).text).to eq("ok")
  end
end
