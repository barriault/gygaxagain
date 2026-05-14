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

      def relative_time
        helpers.time_ago_in_words(event.occurred_at) + " ago"
      end
    end
  end
end
