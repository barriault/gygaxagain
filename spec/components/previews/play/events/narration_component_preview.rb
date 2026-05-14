module Play
  module Events
    class NarrationComponentPreview < ViewComponent::Preview
      def default
        event = Event.new(
          kind: "narration",
          payload: { "text" => "The tavern is quiet. Rain drips from the eaves outside." },
          occurred_at: Time.current
        )
        render Play::Events::NarrationComponent.new(event: event)
      end

      def long_text
        event = Event.new(
          kind: "narration",
          payload: { "text" => ("A long paragraph of narration filling the scene with detail. " * 8) },
          occurred_at: Time.current
        )
        render Play::Events::NarrationComponent.new(event: event)
      end
    end
  end
end
