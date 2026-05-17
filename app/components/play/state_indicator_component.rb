module Play
  class StateIndicatorComponent < ViewComponent::Base
    def initialize(scene:)
      @scene = scene
      @state = Player::SceneStateViewModel.new(scene)
    end
    attr_reader :scene, :state

    def visible? = state.phase == :collecting && (state.undeclared_pcs_this_turn.any? || !state.companion_prompt_offered?)

    def message
      if state.undeclared_pcs_this_turn.any?
        "Waiting on: #{state.undeclared_pcs_this_turn.map(&:name).join(', ')}"
      else
        names = state.undeclared_companions_this_turn.map(&:name).join(", ")
        "Waiting on companion check — declare for #{names} or say 'go'"
      end
    end
  end
end
