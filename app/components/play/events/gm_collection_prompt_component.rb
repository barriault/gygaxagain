module Play
  module Events
    class GmCollectionPromptComponent < ViewComponent::Base
      def initialize(event:)
        @event = event
      end

      attr_reader :event

      def text
        event.payload["text"]
      end

      def dom_id
        helpers.dom_id(event)
      end
    end
  end
end
