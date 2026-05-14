require "rails_helper"

RSpec.describe Llm::Providers::Anthropic do
  let(:adapter) { described_class.new(model: "claude-sonnet-4-6") }
  let(:messages) { [ { role: "user", content: "Hello" } ] }

  before do
    ENV["ANTHROPIC_API_KEY"] = "sk-ant-test-key"
    described_class.reset_client!
  end

  describe "#call (success path)" do
    let(:successful_response_body) do
      {
        id: "msg_01ABCDEF",
        type: "message",
        role: "assistant",
        model: "claude-sonnet-4-6",
        content: [ { type: "text", text: "Hi there!" } ],
        stop_reason: "end_turn",
        usage: {
          input_tokens: 12,
          output_tokens: 7,
          cache_creation_input_tokens: 0,
          cache_read_input_tokens: 0
        }
      }
    end

    before do
      stub_request(:post, "https://api.anthropic.com/v1/messages")
        .to_return(
          status: 200,
          body: successful_response_body.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "returns a successful Llm::Result with parsed text and tokens" do
      result = adapter.call(messages: messages)

      expect(result).to be_a(Llm::Result)
      expect(result).to be_successful
      expect(result.text).to eq("Hi there!")
      expect(result.input_tokens).to eq(12)
      expect(result.output_tokens).to eq(7)
      expect(result.cache_creation_tokens).to eq(0)
      expect(result.cache_read_tokens).to eq(0)
      expect(result.provider_request_id).to eq("msg_01ABCDEF")
      expect(result.error).to be_nil
    end

    it "captures latency_ms" do
      result = adapter.call(messages: messages)
      expect(result.latency_ms).to be_a(Integer)
      expect(result.latency_ms).to be >= 0
    end

    it "captures the request body in prompt_payload" do
      result = adapter.call(system: "You are a narrator.", messages: messages, max_tokens: 256)
      expect(result.prompt_payload).to include(
        "model" => "claude-sonnet-4-6",
        "max_tokens" => 256,
        "system" => "You are a narrator.",
        "messages" => [ { "role" => "user", "content" => "Hello" } ]
      )
    end

    it "captures the response body in response_payload" do
      result = adapter.call(messages: messages)
      expect(result.response_payload).to include(
        "id" => "msg_01ABCDEF",
        "content" => [ { "type" => "text", "text" => "Hi there!" } ]
      )
    end

    it "captures cache token counts when present" do
      stub_request(:post, "https://api.anthropic.com/v1/messages")
        .to_return(
          status: 200,
          body: successful_response_body.merge(
            usage: {
              input_tokens: 12,
              output_tokens: 7,
              cache_creation_input_tokens: 1500,
              cache_read_input_tokens: 800
            }
          ).to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = adapter.call(messages: messages)
      expect(result.cache_creation_tokens).to eq(1500)
      expect(result.cache_read_tokens).to eq(800)
    end

    it "omits the system parameter when not provided" do
      adapter.call(messages: messages)

      expect(WebMock).to have_requested(:post, "https://api.anthropic.com/v1/messages")
        .with { |req|
          body = JSON.parse(req.body)
          !body.key?("system")
        }
    end
  end

  describe "#call (error paths)" do
    it "captures a 500 server error into result.error and response_payload" do
      stub_request(:post, "https://api.anthropic.com/v1/messages")
        .to_return(status: 500, body: { error: { type: "internal_server_error", message: "boom" } }.to_json)

      result = adapter.call(messages: messages)

      expect(result).not_to be_successful
      expect(result.error).to be_a(Llm::ProviderError)
      expect(result.input_tokens).to eq(0)
      expect(result.output_tokens).to eq(0)
      expect(result.cache_creation_tokens).to eq(0)
      expect(result.cache_read_tokens).to eq(0)
      expect(result.provider_request_id).to be_nil
      expect(result.response_payload).to have_key("error")
      expect(result.response_payload.dig("error", "class")).to be_present
      expect(result.response_payload.dig("error", "message")).to be_present
    end

    it "captures a 429 rate-limit error into result.error" do
      stub_request(:post, "https://api.anthropic.com/v1/messages")
        .to_return(status: 429, body: { error: { type: "rate_limit_error", message: "slow down" } }.to_json)

      result = adapter.call(messages: messages)

      expect(result).not_to be_successful
      expect(result.error).to be_a(Llm::ProviderError)
    end

    it "captures a network timeout into result.error" do
      stub_request(:post, "https://api.anthropic.com/v1/messages").to_timeout

      result = adapter.call(messages: messages)

      expect(result).not_to be_successful
      expect(result.error).to be_a(Llm::ProviderError)
    end

    it "still records prompt_payload and latency_ms on error" do
      stub_request(:post, "https://api.anthropic.com/v1/messages").to_return(status: 500)

      result = adapter.call(messages: messages)

      expect(result.prompt_payload).to include("model" => "claude-sonnet-4-6")
      expect(result.latency_ms).to be_a(Integer)
    end
  end

  describe "#call (config errors)" do
    it "raises Llm::ConfigError when ANTHROPIC_API_KEY is missing" do
      ENV.delete("ANTHROPIC_API_KEY")
      expect { adapter.call(messages: messages) }
        .to raise_error(Llm::ConfigError, /ANTHROPIC_API_KEY/)
    end

    it "raises Llm::ConfigError when ANTHROPIC_API_KEY is blank" do
      ENV["ANTHROPIC_API_KEY"] = ""
      expect { adapter.call(messages: messages) }
        .to raise_error(Llm::ConfigError, /ANTHROPIC_API_KEY/)
    end
  end
end
