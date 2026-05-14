require_relative "error"

module Llm
  module Call
    # Returns the persisted LlmCall record. Raises Llm::ConfigError on
    # missing API key or unknown purpose / model override. Never raises
    # on HTTP errors — those are persisted into the row's response_payload.
    def self.execute(purpose:, messages:, system: nil, max_tokens: 1024,
                     user:, campaign: nil, scene: nil, model: nil)
      adapter = Llm::Provider.for(purpose)
      adapter = override_model(adapter, model) if model

      result = adapter.call(system: system, messages: messages, max_tokens: max_tokens)

      cost_cents = if result.successful?
                     Llm::Pricing.cost_cents(
                       usage: {
                         input:          result.input_tokens,
                         output:         result.output_tokens,
                         cache_creation: result.cache_creation_tokens,
                         cache_read:     result.cache_read_tokens
                       },
                       model: adapter.model
                     )
      else
                     0
      end

      LlmCall.create!(
        user:                  user,
        campaign:              campaign,
        scene_id:              scene&.id,
        purpose:               purpose.to_s,
        provider:              provider_name_for(purpose),
        model:                 adapter.model,
        input_tokens:          result.input_tokens,
        output_tokens:         result.output_tokens,
        cache_creation_tokens: result.cache_creation_tokens,
        cache_read_tokens:     result.cache_read_tokens,
        total_cost_cents:      cost_cents,
        latency_ms:            result.latency_ms,
        provider_request_id:   result.provider_request_id,
        prompt_payload:        result.prompt_payload,
        response_payload:      result.response_payload
      )
    end

    def self.override_model(adapter, model)
      raise Llm::ConfigError, "Unknown model: #{model}" unless Llm::Pricing.known_models.include?(model)
      adapter.class.new(model: model)
    end

    def self.provider_name_for(purpose)
      Llm::Provider::PURPOSES.fetch(purpose)[:provider].to_s
    end
  end
end
