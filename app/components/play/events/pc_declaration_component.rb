module Play
  module Events
    class PcDeclarationComponent < ViewComponent::Base
      def initialize(event:)
        @event = event
      end

      attr_reader :event

      def pc_name
        event.pc&.name || "Unknown PC"
      end

      def text
        event.payload["text"]
      end

      def dom_id
        helpers.dom_id(event)
      end
    end
  end
end
