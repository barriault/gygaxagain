require "rails_helper"

RSpec.describe Llm::Call do
  let(:user) { create(:user) }
  let(:messages) { [ { role: "user", content: "Hello" } ] }

  before do
    ENV["ANTHROPIC_API_KEY"] = "sk-ant-test-key"
  end

  describe ".execute (success path)" do
    let(:successful_response_body) do
      {
        id: "msg_01ABCDEF",
        type: "message",
        role: "assistant",
        model: "claude-sonnet-4-6",
        content: [ { type: "text", text: "Hi!" } ],
        stop_reason: "end_turn",
        usage: { input_tokens: 1_000_000, output_tokens: 500_000,
                 cache_creation_input_tokens: 0, cache_read_input_tokens: 0 }
      }
    end

    before do
      stub_request(:post, "https://api.anthropic.com/v1/messages")
        .to_return(status: 200, body: successful_response_body.to_json,
                   headers: { "Content-Type" => "application/json" })
    end

    it "persists an LlmCall row with full fields" do
      expect {
        described_class.execute(purpose: :diagnostics, messages: messages, user: user)
      }.to change(LlmCall, :count).by(1)

      call = LlmCall.last
      expect(call.user).to eq(user)
      expect(call.campaign).to be_nil
      expect(call.purpose).to eq("diagnostics")
      expect(call.provider).to eq("anthropic")
      expect(call.model).to eq("claude-sonnet-4-6")
      expect(call.input_tokens).to eq(1_000_000)
      expect(call.output_tokens).to eq(500_000)
      expect(call.provider_request_id).to eq("msg_01ABCDEF")
      expect(call.prompt_payload).to include("model" => "claude-sonnet-4-6")
      expect(call.response_payload).to include("id" => "msg_01ABCDEF")
    end

    it "computes total_cost_cents from token usage" do
      call = described_class.execute(purpose: :diagnostics, messages: messages, user: user)
      # 1M input @ $3 = $3.00 = 300 cents
      # 500K output @ $15 = $7.50 = 750 cents
      # total = 1050 cents
      expect(call.total_cost_cents).to eq(1050)
    end

    it "returns the persisted LlmCall record" do
      result = described_class.execute(purpose: :diagnostics, messages: messages, user: user)
      expect(result).to be_a(LlmCall)
      expect(result).to be_persisted
    end

    it "uses the model override when provided" do
      call = described_class.execute(
        purpose: :diagnostics, messages: messages, user: user, model: "claude-haiku-4-5"
      )
      expect(call.model).to eq("claude-haiku-4-5")
      # 1M input @ $1 = $1.00 = 100 cents
      # 500K output @ $5 = $2.50 = 250 cents
      # total = 350 cents
      expect(call.total_cost_cents).to eq(350)
    end

    it "raises Llm::ConfigError on an unknown model override" do
      expect {
        described_class.execute(
          purpose: :diagnostics, messages: messages, user: user, model: "claude-mythical-99"
        )
      }.to raise_error(Llm::ConfigError, /Unknown model/)
    end

    it "associates the call with a campaign when provided" do
      campaign = create(:campaign, user: user)
      call = described_class.execute(
        purpose: :diagnostics, messages: messages, user: user, campaign: campaign
      )
      expect(call.campaign).to eq(campaign)
    end

    it "passes a system prompt through to the adapter" do
      described_class.execute(
        purpose: :diagnostics, messages: messages, user: user, system: "You are a bard."
      )

      expect(WebMock).to have_requested(:post, "https://api.anthropic.com/v1/messages")
        .with { |req| JSON.parse(req.body)["system"] == "You are a bard." }
    end
  end

  describe ".execute (HTTP error)" do
    before do
      stub_request(:post, "https://api.anthropic.com/v1/messages")
        .to_return(status: 500, body: { error: { type: "internal_server_error", message: "boom" } }.to_json)
    end

    it "still persists an LlmCall row" do
      expect {
        described_class.execute(purpose: :diagnostics, messages: messages, user: user)
      }.to change(LlmCall, :count).by(1)
    end

    it "writes tokens=0 and cost=0 on error" do
      call = described_class.execute(purpose: :diagnostics, messages: messages, user: user)
      expect(call.input_tokens).to eq(0)
      expect(call.output_tokens).to eq(0)
      expect(call.total_cost_cents).to eq(0)
    end

    it "captures the error in response_payload" do
      call = described_class.execute(purpose: :diagnostics, messages: messages, user: user)
      expect(call.response_payload).to have_key("error")
      expect(call).not_to be_successful
    end
  end

  describe ".execute (config error)" do
    it "raises Llm::ConfigError without persisting a row when API key is missing" do
      ENV.delete("ANTHROPIC_API_KEY")
      expect {
        expect {
          described_class.execute(purpose: :diagnostics, messages: messages, user: user)
        }.to raise_error(Llm::ConfigError)
      }.not_to change(LlmCall, :count)
    end

    it "raises Llm::ConfigError on an unknown purpose" do
      expect {
        described_class.execute(purpose: :fortune_telling, messages: messages, user: user)
      }.to raise_error(Llm::ConfigError, /Unknown purpose/)
    end
  end
end
