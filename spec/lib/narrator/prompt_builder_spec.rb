require "rails_helper"

RSpec.describe Narrator::PromptBuilder do
  let(:campaign) { create(:campaign, name: "Phandalin", description: "Hook.") }
  let!(:aragorn) { create(:player_character, campaign:, name: "Aragorn", role: "pc", notes: "PC notes") }
  let!(:caine)   { create(:player_character, campaign:, name: "Caine",   role: "companion") }
  before         { campaign.update!(main_character: aragorn) }
  let(:scene)    { create(:scene, campaign:, title: "Cemetery", summary: "Old graves.") }
  before         { create(:scene_secret, scene:, label: "Encounter", content: "2 skeletons") }

  context "framing call (zero events)" do
    subject(:prompt) { described_class.framing(scene:) }

    it "produces three system blocks" do
      expect(prompt.system.length).to eq(3)
      expect(prompt.system.map { _1[:type] }).to eq(%w[text text text])
    end

    it "interpolates PC and companion names into the system prompt" do
      expect(prompt.system[0][:text]).to include("Aragorn")
      expect(prompt.system[0][:text]).to include("Caine")
    end

    it "includes scene_secrets content in the scene context block" do
      expect(prompt.system[2][:text]).to include("2 skeletons")
    end

    it "messages contains only the framing kickoff" do
      expect(prompt.messages.length).to eq(1)
      expect(prompt.messages.first[:role]).to eq("user")
      expect(prompt.messages.first[:content]).to include("Scene start")
      expect(prompt.messages.first[:content]).to include("Aragorn")
    end

    it "sets stop_sequences to ]]" do
      expect(prompt.stop_sequences).to eq([ "]]" ])
    end

    it "sets cache_breakpoints for the three system blocks" do
      expect(prompt.cache_breakpoints).to include(0, 1, 2)
    end
  end

  context "resolution call (turn declarations collected)" do
    before do
      create(:event, scene:, kind: "pc_declaration", pc: aragorn, turn_number: 1,
             payload: { "text" => "I push the door open." })
    end

    subject(:prompt) do
      described_class.resolution(scene:, current_turn_declarations: [
        { pc: aragorn, text: "I push the door open." }
      ])
    end

    it "builds a user message labeled [Turn N]" do
      expect(prompt.messages.last[:role]).to eq("user")
      expect(prompt.messages.last[:content]).to include("[Turn 1]")
      expect(prompt.messages.last[:content]).to include("Aragorn declares: I push the door open.")
    end

    it "filters gm_collection_prompt events from history" do
      create(:event, scene:, kind: "gm_collection_prompt", turn_number: 1, payload: { "text" => "And the others?" })
      expect(prompt.messages.last[:content]).not_to include("And the others?")
    end

    it "adds a negative cache breakpoint on the second-to-last assistant when prior turns exist" do
      # Add a prior completed turn
      create(:event, scene:, kind: "pc_declaration", pc: aragorn, turn_number: 1, payload: { "text" => "look" })
      create(:event, scene:, kind: "narration", turn_number: 1, payload: { "text" => "You see things. What do you do?" })
      create(:event, scene:, kind: "pc_declaration", pc: aragorn, turn_number: 2, payload: { "text" => "open" })
      prompt2 = described_class.resolution(scene:, current_turn_declarations: [ { pc: aragorn, text: "open" } ])
      assistant_indices = prompt2.messages.each_with_index.select { |m, _| m[:role] == "assistant" }.map(&:last)
      expect(prompt2.cache_breakpoints).to include(-2) if assistant_indices.length >= 1
    end
  end

  context "continuation call (after a mid-turn dice roll)" do
    before do
      create(:event, scene:, kind: "pc_declaration", pc: aragorn, turn_number: 1,
             payload: { "text" => "I approach the captain." })
      create(:event, scene:, kind: "narration", turn_number: 1,
             payload: { "text" => "He straightens. [[1d20+5 — Aragorn Insight on the captain]]" })
      create(:event, scene:, kind: "dice_roll", pc: aragorn, turn_number: 1,
             payload: { "expression" => "1d20+5", "result" => 17, "reason" => "Insight on the captain" })
    end

    subject(:prompt) do
      described_class.continuation(scene:, latest_roll: scene.events.where(kind: "dice_roll").last)
    end

    it "ends with a user message containing only the roll result" do
      expect(prompt.messages.last[:role]).to eq("user")
      expect(prompt.messages.last[:content]).to include("Aragorn rolled 1d20+5 = 17")
      expect(prompt.messages.last[:content]).not_to include("approach the captain")
    end

    it "includes the partial narration as the preceding assistant message" do
      assistant_idx = prompt.messages.rindex { _1[:role] == "assistant" }
      expect(prompt.messages[assistant_idx][:content]).to include("He straightens.")
    end
  end

  describe "asymmetry-NOT-protected (narrator prompt is DM-side)" do
    # PromptBuilder *should* include secrets — this is not a leak, it's the contract.
    # The asymmetry meta-spec covers Player VMs and Play components, not PromptBuilder.
    it "includes scene_secret content in scene block" do
      prompt = described_class.framing(scene:)
      expect(prompt.system[2][:text]).to include("2 skeletons")
    end
  end
end
