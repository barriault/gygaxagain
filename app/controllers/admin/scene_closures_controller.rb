module Admin
  class SceneClosuresController < Admin::ApplicationController
    before_action :load_scene

    def create
      if @scene.closed?
        redirect_to admin_campaign_path(@scene.campaign), alert: "Scene already closed."
        return
      end

      @scene.update!(closed_at: Time.current)
      SceneAuditJob.perform_later(@scene.id)
      redirect_to admin_campaign_path(@scene.campaign),
                  notice: "Scene closed; audit running."
    end

    private

    def load_scene
      @scene = current_user.campaigns.find(params[:campaign_id]).scenes.find(params[:scene_id])
    end
  end
end
