require_relative "error"

module Llm
  module Provider
    PURPOSES = {
      diagnostics:         { provider: :anthropic, model: "claude-sonnet-4-6" },
      narration:           { provider: :anthropic, model: "claude-sonnet-4-6" },
      bookkeeper_audit:    { provider: :anthropic, model: "claude-sonnet-4-6" },
      intake_long_context: { provider: :anthropic, model: "claude-sonnet-4-6" },
      declaration_parsing: { provider: :anthropic, model: "claude-haiku-4-5" }
    }.freeze

    def self.for(purpose)
      config = PURPOSES.fetch(purpose) do
        raise Llm::ConfigError, "Unknown purpose: #{purpose.inspect}"
      end

      adapter_class_for(config[:provider]).new(model: config[:model])
    end

    def self.adapter_class_for(provider)
      case provider
      when :anthropic then Llm::Providers::Anthropic
      else raise Llm::ConfigError, "Unknown provider: #{provider.inspect}"
      end
    end
  end
end
