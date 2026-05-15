module Admin
  class SceneAuditsController < Admin::ApplicationController
    before_action :load_scene

    def show
      @audit = @scene.audit
      render Admin::SceneAudits::ShowComponent.new(scene: @scene, audit: @audit)
    end

    private

    def load_scene
      @scene = current_user.campaigns.find(params[:campaign_id]).scenes.find(params[:scene_id])
    end
  end
end
