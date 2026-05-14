module Llm
  module Providers
    class Anthropic
      attr_reader :model

      def initialize(model:)
        @model = model
      end

      # Full implementation lands in Task 7.
      def call(system: nil, messages:, max_tokens: 1024)
        raise NotImplementedError, "Implemented in Phase 4.7"
      end

      def self.sdk_client
        @sdk_client ||= ::Anthropic::Client.new(api_key: ENV.fetch("ANTHROPIC_API_KEY"))
      end

      def self.reset_client!
        @sdk_client = nil
      end
    end
  end
end
