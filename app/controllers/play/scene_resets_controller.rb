module Play
  # Alpha-only: clear a scene's play history (events + LLM calls) so you can
  # restart from a clean framing. Preserves scene + campaign + party setup.
  # Useful during playtesting when the narrator gets into a bad state or
  # you want to retry a scene from scratch.
  class SceneResetsController < ::ApplicationController
    def create
      scene = Scene.find(params[:scene_id])
      raise ActiveRecord::RecordNotFound unless current_user.campaigns.exists?(id: scene.campaign_id)

      Event.transaction do
        events_count = scene.events.count
        llm_count    = LlmCall.where(scene_id: scene.id).count
        scene.events.destroy_all
        LlmCall.where(scene_id: scene.id).delete_all
        Rails.logger.info("[SceneReset] scene=#{scene.id} deleted events=#{events_count} llm_calls=#{llm_count}")
      end

      redirect_to play_campaign_scene_url(scene.campaign, scene),
                  notice: "Scene history cleared. The scene will reframe on load."
    end
  end
end
