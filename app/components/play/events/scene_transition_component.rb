module Play
  module Events
    class SceneTransitionComponent < ViewComponent::Base
      def initialize(event:)
        @event = event
      end

      attr_reader :event

      def reason
        event.payload["reason"].to_s
      end

      def relative_time
        helpers.time_ago_in_words(event.occurred_at) + " ago"
      end
    end
  end
end
