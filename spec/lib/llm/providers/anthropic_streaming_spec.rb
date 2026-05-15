require "rails_helper"

RSpec.describe Llm::Providers::Anthropic, "#call_streaming" do
  let(:adapter) { described_class.new(model: "claude-sonnet-4-6") }
  let(:messages) { [ { role: "user", content: "Hi." } ] }

  before do
    allow(Rails.application.credentials).to receive(:dig).with(:anthropic, :api_key).and_return("sk-test")
    described_class.reset_client!
  end

  describe "happy path" do
    before do
      stub_anthropic_streaming(
        text_chunks: [ "Hello ", "world", "." ],
        input_tokens: 12, output_tokens: 7,
        cache_creation_tokens: 100, cache_read_tokens: 200
      )
    end

    it "yields each delta in order" do
      received = []
      adapter.call_streaming(messages: messages) { |text:| received << text }
      expect(received).to eq([ "Hello ", "world", "." ])
    end

    it "returns an Llm::Result with concatenated text and tokens" do
      result = adapter.call_streaming(messages: messages)
      expect(result.successful?).to be(true)
      expect(result.text).to eq("Hello world.")
      expect(result.input_tokens).to eq(12)
      expect(result.output_tokens).to eq(7)
      expect(result.cache_creation_tokens).to eq(100)
      expect(result.cache_read_tokens).to eq(200)
      expect(result.provider_request_id).to start_with("msg_test_")
    end

    it "captures latency_ms" do
      result = adapter.call_streaming(messages: messages)
      expect(result.latency_ms).to be >= 0
    end
  end

  describe "cache_breakpoints" do
    before { stub_anthropic_streaming(text_chunks: [ "x" ]) }

    it "decorates the indicated system block" do
      adapter.call_streaming(
        system: [ { type: "text", text: "rules" }, { type: "text", text: "roster" } ],
        messages: messages,
        cache_breakpoints: [ 0 ]
      )

      expect(WebMock).to have_requested(:post, "https://api.anthropic.com/v1/messages")
        .with { |req|
          body = JSON.parse(req.body)
          body["system"][0]["cache_control"] == { "type" => "ephemeral", "ttl" => "5m" }
        }
    end
  end

  describe "error path" do
    before { stub_anthropic_streaming_error(status: 500, message: "boom") }

    it "returns an errored result" do
      result = adapter.call_streaming(messages: messages)
      expect(result.successful?).to be(false)
      expect(result.response_payload).to have_key("error")
      expect(result.error).to be_a(Llm::ProviderError)
    end
  end

  describe "missing API key" do
    before do
      allow(Rails.application.credentials).to receive(:dig).with(:anthropic, :api_key).and_return(nil)
      described_class.reset_client!
    end

    it "raises Llm::ConfigError" do
      expect {
        adapter.call_streaming(messages: messages)
      }.to raise_error(Llm::ConfigError, /API key/)
    end
  end
end
