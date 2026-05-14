module Play
  module Events
    class OracleQueryComponent < ViewComponent::Base
      def initialize(event:)
        @event = event
      end

      attr_reader :event

      def question
        event.payload["question"].to_s
      end

      def answer
        event.payload["answer"].to_s
      end

      def likelihood
        event.payload["likelihood"].to_s
      end

      def chaos
        event.payload["chaos"]
      end

      def relative_time
        helpers.time_ago_in_words(event.occurred_at) + " ago"
      end

      def random_event_triggered?
        event.payload["random_event_triggered"] == true
      end
    end
  end
end
