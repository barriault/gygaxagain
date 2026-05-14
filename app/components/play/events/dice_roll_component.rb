module Play
  module Events
    class DiceRollComponent < ViewComponent::Base
      def initialize(event:)
        @event = event
      end

      attr_reader :event

      def expression
        event.payload["expression"].to_s
      end

      def result
        event.payload["result"]
      end

      def breakdown
        event.payload["breakdown"]
      end

      def breakdown?
        breakdown.is_a?(Array) && breakdown.any?
      end

      def relative_time
        helpers.time_ago_in_words(event.occurred_at) + " ago"
      end
    end
  end
end
