require_relative "../error"
require_relative "../result"

module Llm
  module Providers
    class Anthropic
      attr_reader :model

      def initialize(model:)
        @model = model
      end

      # Returns Llm::Result. Never raises on HTTP/transport errors —
      # those are captured into result.error. Raises Llm::ConfigError
      # if the API key is missing from Rails credentials.
      def call(system: nil, messages:, max_tokens: 1024)
        api_key = self.class.api_key
        raise Llm::ConfigError, "Anthropic API key not configured (credentials.anthropic.api_key)" if api_key.blank?

        request_body = {
          model: model,
          max_tokens: max_tokens,
          messages: messages
        }
        request_body[:system] = system if system.present?

        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        begin
          response = self.class.sdk_client.messages.create(**request_body)
          latency_ms = elapsed_ms(started_at)

          Llm::Result.new(
            text:                  response.content.first.text,
            input_tokens:          response.usage.input_tokens.to_i,
            output_tokens:         response.usage.output_tokens.to_i,
            cache_creation_tokens: cache_creation_from(response.usage),
            cache_read_tokens:     cache_read_from(response.usage),
            provider_request_id:   response.id,
            prompt_payload:        request_body.deep_stringify_keys,
            response_payload:      JSON.parse(response.to_json),
            latency_ms:            latency_ms,
            error:                 nil
          )
        rescue ::Anthropic::Errors::Error => e
          latency_ms = elapsed_ms(started_at)
          Llm::Result.new(
            text: nil,
            input_tokens: 0, output_tokens: 0,
            cache_creation_tokens: 0, cache_read_tokens: 0,
            provider_request_id: nil,
            prompt_payload: request_body.deep_stringify_keys,
            response_payload: { "error" => { "class" => e.class.name, "message" => e.message } },
            latency_ms: latency_ms,
            error: Llm::ProviderError.new(
              provider_class:   e.class.name,
              provider_message: e.message
            )
          )
        end
      end

      def self.sdk_client
        @sdk_client ||= ::Anthropic::Client.new(api_key: api_key)
      end

      def self.api_key
        Rails.application.credentials.dig(:anthropic, :api_key)
      end

      def self.reset_client!
        @sdk_client = nil
      end

      private

      def elapsed_ms(started_at)
        ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
      end

      def cache_creation_from(usage)
        return 0 unless usage.respond_to?(:cache_creation_input_tokens)
        value = usage.cache_creation_input_tokens
        value.nil? ? 0 : value.to_i
      end

      def cache_read_from(usage)
        return 0 unless usage.respond_to?(:cache_read_input_tokens)
        value = usage.cache_read_input_tokens
        value.nil? ? 0 : value.to_i
      end
    end
  end
end
