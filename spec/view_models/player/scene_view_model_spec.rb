require "rails_helper"

RSpec.describe Player::SceneViewModel do
  let(:scene) { create(:scene, title: "The Tavern", summary: "A noisy hall.") }
  subject(:vm) { described_class.new(scene) }

  describe "exposed attributes" do
    it "exposes id, title, summary, events" do
      expect(described_class.exposed_attrs).to eq(%i[id title summary events])
    end

    it "returns title and summary" do
      expect(vm.title).to eq("The Tavern")
      expect(vm.summary).to eq("A noisy hall.")
    end
  end

  describe "#events" do
    it "wraps events in Player::EventViewModel ordered by occurred_at" do
      older  = create(:event, scene: scene, kind: "narration", payload: { "text" => "first" }, occurred_at: 2.minutes.ago)
      newer  = create(:event, scene: scene, kind: "narration", payload: { "text" => "second" }, occurred_at: 1.minute.ago)

      events = vm.events
      expect(events.length).to eq(2)
      expect(events).to all(be_a(Player::EventViewModel))
      expect(events.first.id).to eq(older.id)
      expect(events.last.id).to eq(newer.id)
    end

    it "returns an empty array on a fresh scene" do
      expect(vm.events).to eq([])
    end
  end

  describe "asymmetry" do
    let!(:faction) { create(:faction, :with_secrets, campaign: scene.campaign) }
    let!(:npc)     { create(:npc, :with_secrets, campaign: scene.campaign) }

    before do
      create(:event, scene: scene, kind: "narration", payload: { "text" => "Nothing hidden here." })
    end

    it "does not leak secrets via events" do
      expect(vm).not_to leak_secrets_of(faction, npc)
    end

    it "does not expose campaign or factions/npcs as attrs" do
      expect(described_class.exposed_attrs).not_to include(:campaign, :factions, :npcs)
    end
  end
end
