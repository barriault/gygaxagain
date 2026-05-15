module Play
  module Events
    module Component
      REGISTRY = {
        "narration"        => NarrationComponent,
        "player_action"    => PlayerActionComponent,
        "dice_roll"        => DiceRollComponent,
        "oracle_query"     => OracleQueryComponent,
        "scene_transition" => SceneTransitionComponent
      }.freeze

      def self.for(event)
        REGISTRY.fetch(event.kind) do
          raise ArgumentError, "no component registered for event kind #{event.kind.inspect}"
        end
      end
    end
  end
end
