module Play
  class NarrationsController < ::ApplicationController
    before_action :load_scene

    def create
      text = params.require(:narration).permit(:text).fetch(:text, "").to_s.strip

      if text.blank?
        return render turbo_stream: turbo_stream.replace(
          helpers.dom_id(@scene, :narration_form),
          Play::Narration::FormComponent.new(scene: @scene, text: text, error: "type something to do")
        ), status: :unprocessable_content
      end

      player_action_event = nil
      narration_event     = nil

      Event.transaction do
        # Create in the order they should appear in the log (occurred_at default
        # is set in a before_validation hook to Time.current, so creation order
        # matches occurred_at order). The player_action's narration_event_id
        # link is populated in a follow-up update once the narration row exists.
        player_action_event = @scene.events.create!(
          kind: "player_action",
          payload: { "text" => text, "narration_event_id" => nil }
        )
        narration_event = @scene.events.create!(
          kind: "narration",
          payload: {
            "text" => "", "status" => "streaming", "llm_call_id" => nil,
            "player_action_event_id" => player_action_event.id
          }
        )
        player_action_event.update!(payload: player_action_event.payload.merge(
          "narration_event_id" => narration_event.id
        ))
      end

      NarrationJob.perform_later(narration_event.id)

      respond_to do |f|
        f.turbo_stream { render turbo_stream: stream_appends_and_form_reset(player_action_event, narration_event) }
        f.html { redirect_to play_campaign_scene_path(@scene.campaign, @scene) }
      end
    end

    private

    def load_scene
      @scene = current_user.campaigns.find(params[:campaign_id]).scenes.find(params[:scene_id])
    end

    def stream_appends_and_form_reset(player_action_event, narration_event)
      [
        turbo_stream.append(helpers.dom_id(@scene, :log),
                            Play::Events::Component.for(player_action_event).new(event: player_action_event)),
        turbo_stream.append(helpers.dom_id(@scene, :log),
                            Play::Events::Component.for(narration_event).new(event: narration_event)),
        turbo_stream.remove(helpers.dom_id(@scene, :log_empty)),
        turbo_stream.replace(helpers.dom_id(@scene, :narration_form),
                             Play::Narration::FormComponent.new(scene: @scene))
      ]
    end
  end
end
