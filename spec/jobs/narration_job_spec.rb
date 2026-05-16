require "rails_helper"

RSpec.describe NarrationJob, type: :job do
  include ActiveJob::TestHelper

  let(:campaign) { create(:campaign) }
  let!(:aragorn) { create(:player_character, campaign:, name: "Aragorn", role: "pc").tap { campaign.update!(main_character: _1) } }
  let(:scene)    { create(:scene, campaign:) }

  before do
    Llm::Providers::Anthropic.reset_client!
    stub_anthropic_streaming(text_chunks: [ "OK. ", "What do you do?" ])
  end

  describe "framing trigger" do
    it "calls PromptBuilder.framing and persists the streamed text" do
      narration = scene.events.create!(kind: "narration", turn_number: 1,
                                       payload: { "text" => "", "status" => "streaming", "trigger" => "framing" })
      described_class.perform_now(scene_id: scene.id, narration_event_id: narration.id, trigger: "framing")
      expect(narration.reload.payload["text"]).to eq("OK. What do you do?")
      expect(narration.reload.payload["status"]).to eq("complete")
    end
  end

  describe "resolution trigger" do
    before do
      create(:event, scene:, kind: "pc_declaration", pc: aragorn, turn_number: 1,
             payload: { "text" => "I look around." })
    end

    it "calls PromptBuilder.resolution with the turn's declarations" do
      narration = scene.events.create!(kind: "narration", turn_number: 1,
                                       payload: { "text" => "", "status" => "streaming", "trigger" => "resolution" })
      described_class.perform_now(scene_id: scene.id, narration_event_id: narration.id, trigger: "resolution")
      expect(narration.reload.payload["status"]).to eq("complete")
    end
  end

  describe "continuation trigger" do
    before do
      create(:event, scene:, kind: "pc_declaration", pc: aragorn, turn_number: 1, payload: { "text" => "approach" })
      create(:event, scene:, kind: "narration", turn_number: 1,
             payload: { "text" => "He looks up. [[1d20 — Aragorn Insight", "status" => "complete" })
      create(:event, scene:, kind: "dice_roll", pc: aragorn, turn_number: 1,
             payload: { "expression" => "1d20", "result" => 14, "reason" => "Insight" })
    end

    it "calls PromptBuilder.continuation with the latest roll" do
      narration = scene.events.create!(kind: "narration", turn_number: 1,
                                       payload: { "text" => "", "status" => "streaming", "trigger" => "continuation" })
      described_class.perform_now(scene_id: scene.id, narration_event_id: narration.id, trigger: "continuation")
      expect(narration.reload.payload["status"]).to eq("complete")
    end
  end

  describe "errored streams" do
    it "marks the event errored on any exception" do
      allow(Llm::Call).to receive(:execute_streaming).and_raise(StandardError, "boom")
      narration = scene.events.create!(kind: "narration", turn_number: 1,
                                       payload: { "text" => "", "status" => "streaming", "trigger" => "framing" })
      expect {
        described_class.perform_now(scene_id: scene.id, narration_event_id: narration.id, trigger: "framing")
      }.to raise_error(StandardError)
      expect(narration.reload.payload["status"]).to eq("errored")
    end
  end
end
