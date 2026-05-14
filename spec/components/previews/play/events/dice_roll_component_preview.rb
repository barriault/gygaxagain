module Play
  module Events
    class DiceRollComponentPreview < ViewComponent::Preview
      def default
        event = Event.new(
          kind: "dice_roll",
          payload: { "expression" => "1d20", "result" => 15 },
          occurred_at: Time.current
        )
        render Play::Events::DiceRollComponent.new(event: event)
      end

      def with_breakdown
        event = Event.new(
          kind: "dice_roll",
          payload: { "expression" => "2d6+3", "result" => 10, "breakdown" => [ 4, 3, "+3" ] },
          occurred_at: Time.current
        )
        render Play::Events::DiceRollComponent.new(event: event)
      end

      def negative_result
        event = Event.new(
          kind: "dice_roll",
          payload: { "expression" => "1d20-2", "result" => -1, "breakdown" => [ 1, "-2" ] },
          occurred_at: Time.current
        )
        render Play::Events::DiceRollComponent.new(event: event)
      end
    end
  end
end
