require "rails_helper"

RSpec.describe Narrator::AuditPromptBuilder do
  let(:scene) { create(:scene, title: "The Tavern", summary: "A noisy hall.") }

  before do
    create(:event, scene: scene, kind: "player_action", payload: { "text" => "I open the door." }, occurred_at: 2.minutes.ago)
    create(:event, scene: scene, kind: "narration",     payload: { "text" => "The door swings open." }, occurred_at: 1.minute.ago)
  end

  describe ".call" do
    it "returns a Narrator::Prompt" do
      prompt = described_class.call(scene: scene)
      expect(prompt).to be_a(Narrator::Prompt)
    end

    it "puts AuditSystemPrompt.text in the cached system block" do
      prompt = described_class.call(scene: scene)
      expect(prompt.system.length).to eq(1)
      expect(prompt.system[0][:text]).to eq(Narrator::AuditSystemPrompt.text)
      expect(prompt.cache_breakpoints).to eq([ 0 ])
    end

    it "renders all events in the user message ordered by occurred_at" do
      prompt = described_class.call(scene: scene)
      content = prompt.messages.first[:content]
      expect(content).to include("The Tavern")
      expect(content).to include("[player_action")
      expect(content).to include("I open the door.")
      expect(content.index("I open the door.")).to be < content.index("The door swings open.")
    end
  end

  describe "asymmetry" do
    let!(:faction) { create(:faction, :with_secrets, campaign: scene.campaign) }
    let!(:npc)     { create(:npc, :with_secrets, campaign: scene.campaign) }

    it "does not leak secrets in the audit prompt (transitively guaranteed)" do
      prompt = described_class.call(scene: scene)
      expect(prompt.to_s).not_to leak_secrets_of(faction, npc)
    end
  end
end
