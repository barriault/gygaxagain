module Play
  class ComposerComponent < ViewComponent::Base
    def initialize(scene:)
      @scene = scene
      @state = Player::SceneStateViewModel.new(scene)
    end
    attr_reader :scene, :state

    def disabled? = !state.composer_enabled?

    def placeholder
      case state.phase
      when :framing       then "Loading scene…"
      when :awaiting_roll then "Roll the dice above to continue."
      when :collecting    then "Type your action…"
      when :idle          then "What's next?"
      else "Narrating…"
      end
    end

    def submit_path
      helpers.campaign_scene_pc_declarations_path(scene.campaign, scene)
    end
  end
end
