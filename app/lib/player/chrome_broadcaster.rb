module Player
  # Re-renders the sticky composer and state-indicator on the play surface
  # whenever something happens that might change SceneStateViewModel#phase.
  # Without this, the browser's composer keeps the disabled state from when
  # the page was last rendered — e.g. it stays disabled after a continuation
  # narration completes, blocking the player until they refresh.
  module ChromeBroadcaster
    def self.refresh(scene)
      user = scene&.campaign&.user
      return unless user

      stream_key = [ scene, user ]

      Turbo::StreamsChannel.broadcast_replace_to(
        stream_key,
        target:     "scene_#{scene.id}_composer",
        renderable: Play::ComposerComponent.new(scene: scene),
        layout:     false
      )
      Turbo::StreamsChannel.broadcast_replace_to(
        stream_key,
        target:     "scene_#{scene.id}_state_indicator",
        renderable: Play::StateIndicatorComponent.new(scene: scene),
        layout:     false
      )
    end
  end
end
