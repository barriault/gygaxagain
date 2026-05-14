module Play
  module Events
    class SceneTransitionComponentPreview < ViewComponent::Preview
      def default
        event = Event.new(
          kind: "scene_transition",
          payload: { "reason" => "Player chose to leave the tavern." },
          occurred_at: Time.current
        )
        render Play::Events::SceneTransitionComponent.new(event: event)
      end
    end
  end
end
