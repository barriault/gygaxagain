module Play
  class PcDeclarationsController < ::ApplicationController
    def create
      scene = Scene.find(params[:scene_id])
      raise ActiveRecord::RecordNotFound unless current_user.campaigns.exists?(id: scene.campaign_id)

      state = Player::SceneStateViewModel.new(scene)

      result = Narrator::DeclarationLlm.call(
        text:                   params.require(:text),
        campaign:               scene.campaign,
        focus_pc:               focus_pc(scene),
        undeclared_pcs:         state.undeclared_pcs_this_turn,
        undeclared_companions:  state.undeclared_companions_this_turn,
        user:                   current_user,
        scene:                  scene
      )

      handle_result(scene, state, result)
      head :no_content
    end

    private

    def focus_pc(scene)
      last_prompt = scene.events.where(kind: "gm_collection_prompt").order(:occurred_at).last
      return nil unless last_prompt

      pc_id = last_prompt.payload["focus_pc_id"]
      pc_id && scene.campaign.player_characters.find_by(id: pc_id)
    end

    def handle_result(scene, state, result)
      case result
      when Narrator::DeclarationParser::Success
        create_declarations(scene, state, result.declarations)
        advance_turn(scene)
      when Narrator::DeclarationParser::DiceRoll
        DiceRollCreator.call(
          scene:       scene,
          pc:          result.pc,
          expression:  result.expression,
          reason:      nil,
          turn_number: state.current_turn_number
        )
      when Narrator::DeclarationParser::Failure
        create_prompt(scene, state, text: result.reason)
      end
    end

    def create_declarations(scene, state, declarations)
      Event.transaction do
        declarations.each do |d|
          scene.events.create!(
            kind:        "pc_declaration",
            pc:          d[:pc],
            turn_number: state.current_turn_number,
            payload:     { "text" => d[:text] }
          )
        end
      end
    end

    def advance_turn(scene)
      state = Player::SceneStateViewModel.new(scene)
      undeclared_pcs = state.undeclared_pcs_this_turn

      if undeclared_pcs.any?
        create_prompt(scene, state,
                      text:        Narrator::CollectionPrompt.next_pc(undeclared_pcs.map(&:name)),
                      focus_pc_id: undeclared_pcs.first.id)
        return
      end

      unless state.companion_prompt_offered?
        companions = scene.campaign.player_characters.companions.order(:name)
        create_prompt(scene, state,
                      text: Narrator::CollectionPrompt.companion_check(companions.map(&:name)),
                      kind: "companion_check")
        return
      end

      enqueue_resolution(scene, state.current_turn_number)
    end

    def create_prompt(scene, state, text:, focus_pc_id: nil, kind: "general")
      scene.events.create!(
        kind:        "gm_collection_prompt",
        turn_number: state.current_turn_number,
        payload:     { "text" => text, "focus_pc_id" => focus_pc_id, "kind" => kind }.compact
      )
    end

    def enqueue_resolution(scene, turn_number)
      narration = scene.events.create!(
        kind:        "narration",
        turn_number: turn_number,
        payload:     { "text" => "", "status" => "streaming", "trigger" => "resolution" }
      )
      NarrationJob.perform_later(
        scene_id:          scene.id,
        narration_event_id: narration.id,
        trigger:           "resolution"
      )
    end
  end
end
