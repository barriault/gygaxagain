require "bigdecimal"
require_relative "error"

module Llm
  module Pricing
    # USD per million tokens. Verified against
    # https://platform.claude.com/docs/en/about-claude/pricing on 2026-05-14.
    RATES = {
      "claude-sonnet-4-6" => {
        input:          3.00,
        output:         15.00,
        cache_write_5m: 3.75,
        cache_write_1h: 6.00,
        cache_read:     0.30
      },
      "claude-opus-4-7" => {
        input:          5.00,
        output:         25.00,
        cache_write_5m: 6.25,
        cache_write_1h: 10.00,
        cache_read:     0.50
      },
      "claude-haiku-4-5" => {
        input:          1.00,
        output:         5.00,
        cache_write_5m: 1.25,
        cache_write_1h: 2.00,
        cache_read:     0.10
      }
    }.freeze

    PER_MTOK = BigDecimal("1_000_000")

    def self.cost_cents(usage:, model:, cache_ttl: :ephemeral_5m)
      rates = RATES.fetch(model) { raise Llm::ConfigError, "Unknown model: #{model}" }

      cache_write_rate = case cache_ttl
      when :ephemeral_5m then rates[:cache_write_5m]
      when :ephemeral_1h then rates[:cache_write_1h]
      else raise Llm::ConfigError, "Unknown cache_ttl: #{cache_ttl}"
      end

      total_usd = BigDecimal("0")
      total_usd += BigDecimal(usage[:input].to_s)          * BigDecimal(rates[:input].to_s)         / PER_MTOK
      total_usd += BigDecimal(usage[:output].to_s)         * BigDecimal(rates[:output].to_s)        / PER_MTOK
      total_usd += BigDecimal(usage[:cache_creation].to_s) * BigDecimal(cache_write_rate.to_s)      / PER_MTOK
      total_usd += BigDecimal(usage[:cache_read].to_s)     * BigDecimal(rates[:cache_read].to_s)    / PER_MTOK

      (total_usd * BigDecimal("100")).round.to_i
    end

    def self.known_models
      RATES.keys
    end
  end
end
