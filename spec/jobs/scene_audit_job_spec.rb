require "rails_helper"

RSpec.describe SceneAuditJob, type: :job do
  let(:scene) { create(:scene, closed_at: Time.current) }

  before do
    create(:event, scene: scene, kind: "player_action", payload: { "text" => "I look around." })
    create(:event, scene: scene, kind: "narration",     payload: { "text" => "It is dark." })

    allow(Rails.application.credentials).to receive(:dig).with(:anthropic, :api_key).and_return("sk-test")
    Llm::Providers::Anthropic.reset_client!
  end

  describe "happy path with valid JSON response" do
    let(:audit_json) {
      {
        verdict: "pass",
        criteria: [
          { name: "player_agency",            status: "pass", note: "ok" },
          { name: "follow_through",           status: "pass", note: "ok" },
          { name: "over_narration_of_intent", status: "pass", note: "ok" },
          { name: "mechanical_handoff",       status: "pass", note: "ok" }
        ],
        summary: "All good."
      }.to_json
    }

    before do
      stub_request(:post, "https://api.anthropic.com/v1/messages").to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          id: "msg_audit_1", type: "message", role: "assistant", model: "claude-sonnet-4-6",
          content: [{ type: "text", text: audit_json }],
          stop_reason: "end_turn", stop_sequence: nil,
          usage: { input_tokens: 100, output_tokens: 200,
                   cache_creation_input_tokens: 0, cache_read_input_tokens: 0 }
        }.to_json
      )
    end

    it "creates a SceneAudit row with verdict pass and the parsed result" do
      expect {
        described_class.perform_now(scene.id)
      }.to change(SceneAudit, :count).by(1)

      audit = scene.reload.audit
      expect(audit.verdict).to eq("pass")
      expect(audit.result["summary"]).to eq("All good.")
      expect(audit.llm_call.purpose).to eq("bookkeeper_audit")
    end
  end

  describe "JSON parse failure" do
    before do
      stub_request(:post, "https://api.anthropic.com/v1/messages").to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          id: "msg_audit_2", type: "message", role: "assistant", model: "claude-sonnet-4-6",
          content: [{ type: "text", text: "definitely not json" }],
          stop_reason: "end_turn", stop_sequence: nil,
          usage: { input_tokens: 50, output_tokens: 5,
                   cache_creation_input_tokens: 0, cache_read_input_tokens: 0 }
        }.to_json
      )
    end

    it "creates a SceneAudit row with verdict fail and error info" do
      described_class.perform_now(scene.id)
      audit = scene.reload.audit
      expect(audit.verdict).to eq("fail")
      expect(audit.result["error"]).to eq("audit_parse_failed")
      expect(audit.result["raw"]).to include("definitely not json")
    end
  end

  describe "idempotency" do
    let(:audit_json) {
      { verdict: "pass", criteria: [], summary: "ok" }.to_json
    }

    before do
      stub_request(:post, "https://api.anthropic.com/v1/messages").to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          id: "msg_audit_3", type: "message", role: "assistant", model: "claude-sonnet-4-6",
          content: [{ type: "text", text: audit_json }],
          stop_reason: "end_turn", stop_sequence: nil,
          usage: { input_tokens: 1, output_tokens: 1,
                   cache_creation_input_tokens: 0, cache_read_input_tokens: 0 }
        }.to_json
      )
    end

    it "is a no-op on the second call when an audit exists" do
      described_class.perform_now(scene.id)
      expect {
        described_class.perform_now(scene.id)
      }.not_to change(SceneAudit, :count)
    end
  end
end
