module Play
  class ScenesController < ::ApplicationController
    def play
      @scene = current_user
                 .campaigns
                 .find(params[:campaign_id])
                 .scenes
                 .find(params[:id])

      if @scene.events.empty? && !prefetch_request?
        narration = @scene.events.create!(
          kind: "narration",
          turn_number: 1,
          payload: { "text" => "", "status" => "streaming", "trigger" => "framing" }
        )
        NarrationJob.perform_later(scene_id: @scene.id, narration_event_id: narration.id, trigger: "framing")
      end

      render Play::Scenes::PlayComponent.new(scene: @scene)
    end

    private

    # Turbo Drive 8 prefetches links on hover. We don't want hover to fire a
    # framing LLM call. Browsers send Sec-Purpose: prefetch (current spec) or
    # the older Purpose: prefetch header.
    def prefetch_request?
      request.headers["Sec-Purpose"]&.include?("prefetch") ||
        request.headers["Purpose"] == "prefetch" ||
        request.headers["X-Sec-Purpose"] == "prefetch"
    end
  end
end
