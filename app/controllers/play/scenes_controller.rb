module Play
  class ScenesController < ::ApplicationController
    def play
      @scene = current_user
                 .campaigns
                 .find(params[:campaign_id])
                 .scenes
                 .find(params[:id])

      if @scene.events.empty?
        narration = @scene.events.create!(
          kind: "narration",
          turn_number: 1,
          payload: { "text" => "", "status" => "streaming", "trigger" => "framing" }
        )
        NarrationJob.perform_later(scene_id: @scene.id, narration_event_id: narration.id, trigger: "framing")
      end

      render Play::Scenes::PlayComponent.new(scene: @scene)
    end
  end
end
