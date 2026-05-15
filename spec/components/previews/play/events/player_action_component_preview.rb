module Play
  module Events
    class PlayerActionComponentPreview < ViewComponent::Preview
      def default
        event = Event.new(id: 1, kind: "player_action",
                          payload: { "text" => "I push the door open." },
                          occurred_at: 30.seconds.ago)
        render(Play::Events::PlayerActionComponent.new(event: event))
      end

      def long_text
        event = Event.new(id: 2, kind: "player_action",
                          payload: { "text" => "I take a slow look around the entire room — the bar, the rafters, the booths in the back, anyone who might be watching. I'm trying to read the mood." },
                          occurred_at: 2.minutes.ago)
        render(Play::Events::PlayerActionComponent.new(event: event))
      end
    end
  end
end
