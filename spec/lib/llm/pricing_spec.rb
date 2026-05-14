require "rails_helper"

RSpec.describe Llm::Pricing do
  describe ".cost_cents" do
    it "computes Sonnet 4.6 input + output cost" do
      cost = described_class.cost_cents(
        usage: { input: 1_000_000, output: 500_000, cache_creation: 0, cache_read: 0 },
        model: "claude-sonnet-4-6"
      )
      # 1M input @ $3 = $3.00 = 300 cents
      # 500K output @ $15 = $7.50 = 750 cents
      # total = 1050 cents
      expect(cost).to eq(1050)
    end

    it "computes Sonnet 4.6 cache_creation cost (5m default)" do
      cost = described_class.cost_cents(
        usage: { input: 0, output: 0, cache_creation: 1_000_000, cache_read: 0 },
        model: "claude-sonnet-4-6"
      )
      # 1M cache_creation @ $3.75 (5m write) = $3.75 = 375 cents
      expect(cost).to eq(375)
    end

    it "uses 1h cache write rate when cache_ttl: :ephemeral_1h" do
      cost = described_class.cost_cents(
        usage: { input: 0, output: 0, cache_creation: 1_000_000, cache_read: 0 },
        model: "claude-sonnet-4-6",
        cache_ttl: :ephemeral_1h
      )
      # 1M cache_creation @ $6 (1h write) = $6.00 = 600 cents
      expect(cost).to eq(600)
    end

    it "computes Sonnet 4.6 cache_read cost" do
      cost = described_class.cost_cents(
        usage: { input: 0, output: 0, cache_creation: 0, cache_read: 1_000_000 },
        model: "claude-sonnet-4-6"
      )
      # 1M cache_read @ $0.30 = $0.30 = 30 cents
      expect(cost).to eq(30)
    end

    it "rounds sub-cent values to the nearest cent" do
      cost = described_class.cost_cents(
        usage: { input: 1, output: 0, cache_creation: 0, cache_read: 0 },
        model: "claude-sonnet-4-6"
      )
      # 1 input token @ $3/MTok = $0.000003 = 0.0003 cents → rounds to 0
      expect(cost).to eq(0)
    end

    it "computes Opus 4.7 rates correctly" do
      cost = described_class.cost_cents(
        usage: { input: 1_000_000, output: 0, cache_creation: 0, cache_read: 0 },
        model: "claude-opus-4-7"
      )
      # 1M input @ $5 = $5.00 = 500 cents
      expect(cost).to eq(500)
    end

    it "computes Haiku 4.5 rates correctly" do
      cost = described_class.cost_cents(
        usage: { input: 1_000_000, output: 0, cache_creation: 0, cache_read: 0 },
        model: "claude-haiku-4-5"
      )
      # 1M input @ $1 = $1.00 = 100 cents
      expect(cost).to eq(100)
    end

    it "raises Llm::ConfigError for an unknown model" do
      expect {
        described_class.cost_cents(
          usage: { input: 0, output: 0, cache_creation: 0, cache_read: 0 },
          model: "claude-mythical-99"
        )
      }.to raise_error(Llm::ConfigError, /Unknown model/)
    end

    it "raises Llm::ConfigError for an unknown cache_ttl" do
      expect {
        described_class.cost_cents(
          usage: { input: 0, output: 0, cache_creation: 1, cache_read: 0 },
          model: "claude-sonnet-4-6",
          cache_ttl: :forever
        )
      }.to raise_error(Llm::ConfigError, /Unknown cache_ttl/)
    end
  end

  describe ".known_models" do
    it "lists all priced models" do
      expect(described_class.known_models).to contain_exactly(
        "claude-sonnet-4-6", "claude-opus-4-7", "claude-haiku-4-5"
      )
    end
  end
end
