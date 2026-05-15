module Play
  module Events
    class NarrationComponent < ViewComponent::Base
      def initialize(event:)
        @event = event
      end

      attr_reader :event

      def text
        event.payload["text"].to_s
      end

      def status
        event.payload["status"].to_s
      end

      def error_message
        event.payload["error_message"].to_s
      end

      def relative_time
        helpers.time_ago_in_words(event.occurred_at) + " ago"
      end

      def dom_id
        helpers.dom_id(event)
      end
    end
  end
end
