require "rails_helper"

RSpec.describe Player::EventViewModel do
  let(:scene) { create(:scene) }

  describe "exposed attributes" do
    it "exposes id, kind, occurred_at, text, occurred_at_label" do
      expect(described_class.exposed_attrs).to eq(%i[id kind occurred_at text occurred_at_label])
    end
  end

  describe "#text by kind" do
    it "renders narration text" do
      event = create(:event, scene: scene, kind: "narration",
                     payload: { "text" => "The door swings open." })
      expect(described_class.new(event).text).to eq("The door swings open.")
    end

    it "renders player_action text" do
      event = create(:event, scene: scene, kind: "player_action",
                     payload: { "text" => "I open the door." })
      expect(described_class.new(event).text).to eq("I open the door.")
    end

    it "renders dice_roll as expression and result" do
      event = create(:event, scene: scene, kind: "dice_roll",
                     payload: { "expression" => "2d6+3", "result" => 11 })
      expect(described_class.new(event).text).to eq("Rolled 2d6+3 → 11")
    end

    it "renders oracle_query with question, likelihood, chaos, answer" do
      event = create(:event, scene: scene, kind: "oracle_query",
                     payload: { "question" => "Does the door open?",
                                "likelihood" => "50_50", "chaos" => 5, "answer" => "Yes" })
      vm = described_class.new(event)
      expect(vm.text).to eq("Asked: Does the door open? (50_50, chaos 5) → Yes")
    end

    it "renders scene_transition with reason" do
      event = create(:event, scene: scene, kind: "scene_transition",
                     payload: { "reason" => "Travel to the next town." })
      expect(described_class.new(event).text).to eq("Travel to the next town.")
    end
  end

  describe "#occurred_at_label" do
    it "is the iso8601 timestamp" do
      time = Time.zone.parse("2026-05-14T20:00:00Z")
      event = create(:event, scene: scene, kind: "narration", payload: { "text" => "x" }, occurred_at: time)
      expect(described_class.new(event).occurred_at_label).to eq(time.iso8601)
    end
  end

  describe "asymmetry" do
    let!(:faction) { create(:faction, :with_secrets, campaign: scene.campaign) }
    let!(:npc)     { create(:npc, :with_secrets, campaign: scene.campaign) }
    let(:event)    { create(:event, scene: scene, kind: "narration", payload: { "text" => "Nothing hidden here." }) }

    it "does not leak secrets" do
      vm = described_class.new(event)
      expect(vm).not_to leak_secrets_of(faction, npc)
    end
  end
end
