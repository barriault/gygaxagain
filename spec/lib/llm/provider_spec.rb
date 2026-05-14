require "rails_helper"

RSpec.describe Llm::Provider do
  describe ".for" do
    it "returns an Anthropic adapter for :narration with the registered model" do
      adapter = described_class.for(:narration)
      expect(adapter).to be_a(Llm::Providers::Anthropic)
      expect(adapter.model).to eq("claude-sonnet-4-6")
    end

    it "returns an Anthropic adapter for :diagnostics" do
      adapter = described_class.for(:diagnostics)
      expect(adapter).to be_a(Llm::Providers::Anthropic)
      expect(adapter.model).to eq("claude-sonnet-4-6")
    end

    it "returns an Anthropic adapter for :intake_long_context (Gemini placeholder)" do
      adapter = described_class.for(:intake_long_context)
      expect(adapter).to be_a(Llm::Providers::Anthropic)
      expect(adapter.model).to eq("claude-sonnet-4-6")
    end

    it "returns an Anthropic adapter for :bookkeeper_audit" do
      adapter = described_class.for(:bookkeeper_audit)
      expect(adapter).to be_a(Llm::Providers::Anthropic)
      expect(adapter.model).to eq("claude-sonnet-4-6")
    end

    it "raises Llm::ConfigError for an unknown purpose" do
      expect { described_class.for(:fortune_telling) }
        .to raise_error(Llm::ConfigError, /Unknown purpose/)
    end
  end
end
