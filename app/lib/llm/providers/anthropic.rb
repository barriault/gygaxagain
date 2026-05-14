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
      def call(system: nil, messages:, max_tokens: 1024, cache_breakpoints: [])
        api_key = self.class.api_key
        raise Llm::ConfigError, "Anthropic API key not configured (credentials.anthropic.api_key)" if api_key.blank?

        request_body = build_request_body(system: system, messages: messages,
                                          max_tokens: max_tokens, cache_breakpoints: cache_breakpoints)

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

      # Streaming variant. Yields each text delta to &on_chunk as { text: String }.
      # Returns Llm::Result at completion (text accumulates the full response).
      # On error, returns an Llm::Result with `error` populated and any partial text
      # captured into prompt_payload["partial_text"].
      def call_streaming(system: nil, messages:, max_tokens: 4096,
                         cache_breakpoints: [], &on_chunk)
        api_key = self.class.api_key
        raise Llm::ConfigError, "Anthropic API key not configured (credentials.anthropic.api_key)" if api_key.blank?

        request_body = build_request_body(system: system, messages: messages,
                                          max_tokens: max_tokens, cache_breakpoints: cache_breakpoints)

        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        text       = +""

        begin
          stream = self.class.sdk_client.messages.stream(**request_body)
          stream.text.each do |delta|
            text << delta
            on_chunk&.call(text: delta)
          end
          message = stream.accumulated_message
          latency_ms = elapsed_ms(started_at)

          Llm::Result.new(
            text:                  text,
            input_tokens:          message.usage.input_tokens.to_i,
            output_tokens:         message.usage.output_tokens.to_i,
            cache_creation_tokens: cache_creation_from(message.usage),
            cache_read_tokens:     cache_read_from(message.usage),
            provider_request_id:   message.id,
            prompt_payload:        request_body.deep_stringify_keys,
            response_payload:      JSON.parse(message.to_json),
            latency_ms:            latency_ms,
            error:                 nil
          )
        rescue ::Anthropic::Errors::Error => e
          latency_ms = elapsed_ms(started_at)
          Llm::Result.new(
            text: text.presence,
            input_tokens: 0, output_tokens: 0,
            cache_creation_tokens: 0, cache_read_tokens: 0,
            provider_request_id: nil,
            prompt_payload: request_body.deep_stringify_keys.merge("partial_text" => text),
            response_payload: { "error" => { "class" => e.class.name, "message" => e.message } },
            latency_ms: latency_ms,
            error: Llm::ProviderError.new(provider_class: e.class.name, provider_message: e.message)
          )
        end
      end

      # Memoized for the life of the process. Credentials are read once at
      # first call; rotating the key requires a process restart (handled
      # automatically by Heroku release phase on every deploy). `reset_client!`
      # exists for test isolation only.
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

      def build_request_body(system:, messages:, max_tokens:, cache_breakpoints:)
        body = {
          model: model,
          max_tokens: max_tokens,
          messages: messages
        }
        if system.present?
          body[:system] = if cache_breakpoints.any?
                            normalize_system(system, cache_breakpoints)
                          else
                            system
                          end
        elsif cache_breakpoints.any?
          raise Llm::ConfigError, "cache_breakpoints requires a non-nil system parameter"
        end
        body
      end

      def normalize_system(system, cache_breakpoints)
        blocks = case system
                 when String then [{ type: "text", text: system }]
                 when Array  then system.map(&:dup)
                 else             raise Llm::ConfigError, "system must be a String or Array of typed blocks"
                 end
        cache_breakpoints.each do |bp|
          index, ttl = case bp
                       when Integer then [bp, :ephemeral_5m]
                       when Hash    then [bp.fetch(:index), bp.fetch(:ttl, :ephemeral_5m)]
                       end
          blocks[index][:cache_control] = { type: "ephemeral", ttl: ttl_to_anthropic(ttl) }
        end
        blocks
      end

      def ttl_to_anthropic(ttl)
        case ttl
        when :ephemeral_5m then "5m"
        when :ephemeral_1h then "1h"
        else raise Llm::ConfigError, "Unknown cache TTL: #{ttl.inspect}"
        end
      end

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
