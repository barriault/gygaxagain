require "rails_helper"

RSpec.describe NarrationJob, type: :job do
  let(:user)          { create(:user) }
  let(:campaign)      { create(:campaign, user: user) }
  let(:scene)         { create(:scene, campaign: campaign) }
  let!(:player_event) {
    create(:event, scene: scene, kind: "player_action",
           payload: { "text" => "I open the door." })
  }
  let!(:narration_event) {
    create(:event, scene: scene, kind: "narration",
           payload: { "text" => "", "status" => "streaming",
                      "player_action_event_id" => player_event.id, "llm_call_id" => nil })
  }

  before do
    install_turbo_capture!
    allow(Rails.application.credentials).to receive(:dig).with(:anthropic, :api_key).and_return("sk-test")
    Llm::Providers::Anthropic.reset_client!
  end

  describe "happy path" do
    before do
      stub_anthropic_streaming(text_chunks: [ "Hello ", "there", "." ],
                               input_tokens: 10, output_tokens: 4)
    end

    it "accumulates text and finalizes the narration event payload" do
      described_class.perform_now(narration_event.id)
      narration_event.reload

      expect(narration_event.payload["text"]).to eq("Hello there.")
      expect(narration_event.payload["status"]).to eq("complete")
      expect(narration_event.payload["llm_call_id"]).to be_a(Integer)
    end

    it "writes an LlmCall row" do
      expect {
        described_class.perform_now(narration_event.id)
      }.to change(LlmCall, :count).by(1)

      call = LlmCall.last
      expect(call.purpose).to eq("narration")
      expect(call.scene_id).to eq(scene.id)
    end

    it "broadcasts at least one replace to the per-(scene, user) channel" do
      described_class.perform_now(narration_event.id)
      replaces = captured_turbo_broadcasts.select { _1[:method] == :broadcast_replace_to }
      expect(replaces).not_to be_empty
      expect(replaces.first[:args]).to eq([ [ scene, user ] ])
      expect(replaces.first[:kwargs][:target]).to include("event_#{narration_event.id}")
    end
  end

  describe "error path" do
    before { stub_anthropic_streaming_error(status: 500, message: "boom") }

    it "marks the narration event as errored and persists an LlmCall" do
      described_class.perform_now(narration_event.id)
      narration_event.reload

      expect(narration_event.payload["status"]).to eq("errored")
      expect(narration_event.payload["error_message"]).to include("boom")
      expect(narration_event.payload["llm_call_id"]).to be_a(Integer)
    end
  end

  describe "untyped exception rescue" do
    before do
      call_count = 0
      allow(Llm::Call).to receive(:execute_streaming) do |**_kwargs, &block|
        block.call(text: "The ")
        call_count += 1
        raise RuntimeError, "boom"
      end
    end

    it "re-raises the exception so ActiveJob sees the failure" do
      expect {
        described_class.perform_now(narration_event.id)
      }.to raise_error(RuntimeError, "boom")
    end

    it "marks the event as errored with the partial text and error message" do
      begin
        described_class.perform_now(narration_event.id)
      rescue RuntimeError
        # expected
      end

      narration_event.reload
      expect(narration_event.payload["status"]).to eq("errored")
      expect(narration_event.payload["error_message"]).to include("RuntimeError")
      expect(narration_event.payload["error_message"]).to include("boom")
      expect(narration_event.payload["text"]).to include("The ")
    end
  end
end
