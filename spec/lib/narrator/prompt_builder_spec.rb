require "rails_helper"

RSpec.describe Narrator::PromptBuilder do
  let(:campaign) { create(:campaign, name: "Test Campaign", description: "A short description.") }
  let(:scene)    { create(:scene, campaign: campaign, title: "The Tavern", summary: "A noisy hall.") }
  let!(:faction) { create(:faction, :with_secrets, campaign: campaign, name: "The Cult", public_description: "Allegedly charitable.") }
  let!(:npc)     { create(:npc, :with_secrets, campaign: campaign, name: "Old Tom", public_description: "Bartender.", location: "The Tavern") }

  describe ".call" do
    it "returns a Narrator::Prompt with three system blocks and one user message" do
      prompt = described_class.call(scene: scene, player_action_text: "I look around.")

      expect(prompt).to be_a(Narrator::Prompt)
      expect(prompt.system.length).to eq(3)
      expect(prompt.messages).to eq([ { role: "user", content: "I look around." } ])
      expect(prompt.cache_breakpoints).to eq([ 0, 1 ])
    end

    it "includes the rules block first" do
      prompt = described_class.call(scene: scene, player_action_text: "x")
      expect(prompt.system[0][:text]).to eq(Narrator::SystemPrompt.text)
    end

    it "includes the campaign and roster in block 1" do
      prompt = described_class.call(scene: scene, player_action_text: "x")
      block = prompt.system[1][:text]
      expect(block).to include("Test Campaign")
      expect(block).to include("A short description.")
      expect(block).to include("The Cult")
      expect(block).to include("Allegedly charitable.")
      expect(block).to include("Old Tom")
      expect(block).to include("Bartender.")
      expect(block).to include("The Tavern")
    end

    it "includes the scene context and recent events in block 2" do
      create(:event, scene: scene, kind: "narration", payload: { "text" => "It is dark." })
      prompt = described_class.call(scene: scene, player_action_text: "x")
      block = prompt.system[2][:text]
      expect(block).to include("The Tavern")
      expect(block).to include("A noisy hall.")
      expect(block).to include("It is dark.")
    end
  end

  describe "#input_view_models" do
    it "returns only Player::* view models" do
      builder = described_class.new(scene: scene, player_action_text: "x")
      vms = builder.input_view_models
      expect(vms).not_to be_empty
      expect(vms).to all(satisfy { |vm| vm.class.name.start_with?("Player::") })
    end
  end

  describe "asymmetry" do
    it "does not leak any faction or NPC secret content into the rendered prompt" do
      prompt = described_class.call(scene: scene, player_action_text: "I look around.")
      expect(prompt.to_s).not_to leak_secrets_of(faction, npc)
    end
  end

  describe "event window truncation" do
    before do
      35.times do |i|
        create(:event, scene: scene, kind: "narration", payload: { "text" => "Event #{i}" }, occurred_at: i.minutes.ago)
      end
    end

    it "includes a truncation marker when more than RECENT_EVENT_WINDOW events exist" do
      prompt = described_class.call(scene: scene, player_action_text: "x")
      block = prompt.system[2][:text]
      expect(block).to include("[5 earlier events truncated for context]")
    end

    it "includes only the last RECENT_EVENT_WINDOW events" do
      prompt = described_class.call(scene: scene, player_action_text: "x")
      block = prompt.system[2][:text]
      # The 5 oldest events should be excluded; sample one.
      expect(block).not_to include("Event 30")
      # The most recent should be included.
      expect(block).to include("Event 0")
    end
  end
end
