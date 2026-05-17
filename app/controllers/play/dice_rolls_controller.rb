module Play
  class DiceRollsController < ::ApplicationController
    before_action :load_scene

    def create
      expression = params.require(:dice_roll).permit(:expression).fetch(:expression, "").to_s

      begin
        result = ::Dice::Roll.call(expression)
      rescue ::Dice::ParseError => e
        return respond_with_error(expression: expression, message: e.message)
      end

      # Capture phase + turn_number BEFORE creating the dice_roll event so
      # we stamp it with the current turn (rolls without turn_number get
      # dropped from completed_turn_messages in subsequent prompts).
      state = Player::SceneStateViewModel.new(@scene)
      current_turn = state.current_turn_number

      event = @scene.events.create!(
        kind: "dice_roll",
        occurred_at: Time.current,
        turn_number: current_turn,
        payload: {
          "expression" => result.expression,
          "result"     => result.total,
          "breakdown"  => result.breakdown,
          "rolls"      => result.rolls
        }
      )

      # Enqueue continuation if scene is awaiting a roll
      if state.phase == :awaiting_roll
        narration = @scene.events.create!(
          kind: "narration",
          turn_number: state.current_turn_number,
          payload: { "text" => "", "status" => "streaming", "trigger" => "continuation" }
        )
        NarrationJob.perform_later(scene_id: @scene.id, narration_event_id: narration.id, trigger: "continuation")
      end

      respond_to do |f|
        f.turbo_stream { render turbo_stream: stream_success(event) }
        f.html { redirect_to play_campaign_scene_path(@scene.campaign, @scene) }
      end
    end

    private

    def load_scene
      @scene = current_user
                 .campaigns
                 .find(params[:campaign_id])
                 .scenes
                 .find(params[:scene_id])
    end

    def stream_success(event)
      [
        turbo_stream.append(
          helpers.dom_id(@scene, :log),
          Play::Events::Component.for(event).new(event: event)
        ),
        turbo_stream.remove(helpers.dom_id(@scene, :log_empty)),
        turbo_stream.replace(
          helpers.dom_id(@scene, :dice_form),
          Play::Dice::FormComponent.new(scene: @scene)
        )
      ]
    end

    def respond_with_error(expression:, message:)
      respond_to do |f|
        f.turbo_stream do
          render turbo_stream: turbo_stream.replace(
                   helpers.dom_id(@scene, :dice_form),
                   Play::Dice::FormComponent.new(scene: @scene, expression: expression, error: message)
                 ),
                 status: :unprocessable_content
        end
        f.html do
          redirect_to play_campaign_scene_path(@scene.campaign, @scene),
                      alert: message
        end
      end
    end
  end
end
