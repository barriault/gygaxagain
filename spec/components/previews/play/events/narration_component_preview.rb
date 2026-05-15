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

      def streaming
        event = Event.new(id: 10, kind: "narration",
                          payload: { "text" => "The bartender looks up", "status" => "streaming" },
                          occurred_at: 5.seconds.ago)
        render(Play::Events::NarrationComponent.new(event: event))
      end

      def complete
        event = Event.new(id: 11, kind: "narration",
                          payload: { "text" => "The bartender looks up. He waves you over.", "status" => "complete" },
                          occurred_at: 1.minute.ago)
        render(Play::Events::NarrationComponent.new(event: event))
      end

      def errored
        event = Event.new(id: 12, kind: "narration",
                          payload: { "text" => "The bartender", "status" => "errored",
                                     "error_message" => "rate limit exceeded" },
                          occurred_at: 10.seconds.ago)
        render(Play::Events::NarrationComponent.new(event: event))
      end
    end
  end
end
