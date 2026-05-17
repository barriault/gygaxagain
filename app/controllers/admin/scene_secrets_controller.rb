module Admin
  class SceneSecretsController < Admin::ApplicationController
    before_action :load_campaign_and_scene
    before_action :load_scene_secret, only: %i[show edit update destroy]

    def index
      secrets = @scene.scene_secrets.order(:label)
      render Admin::SceneSecrets::IndexComponent.new(campaign: @campaign, scene: @scene, scene_secrets: secrets)
    end

    def show
      render Admin::SceneSecrets::ShowComponent.new(campaign: @campaign, scene: @scene, scene_secret: @scene_secret)
    end

    def new
      @scene_secret = @scene.scene_secrets.new
      render Admin::SceneSecrets::FormComponent.new(campaign: @campaign, scene: @scene, scene_secret: @scene_secret)
    end

    def create
      @scene_secret = @scene.scene_secrets.new(scene_secret_params)
      if @scene_secret.save
        redirect_to admin_campaign_scene_scene_secrets_path(@campaign, @scene), notice: "Scene secret created."
      else
        render Admin::SceneSecrets::FormComponent.new(campaign: @campaign, scene: @scene, scene_secret: @scene_secret),
               status: :unprocessable_content
      end
    end

    def edit
      render Admin::SceneSecrets::FormComponent.new(campaign: @campaign, scene: @scene, scene_secret: @scene_secret)
    end

    def update
      if @scene_secret.update(scene_secret_params)
        redirect_to admin_campaign_scene_scene_secrets_path(@campaign, @scene), notice: "Scene secret updated."
      else
        render Admin::SceneSecrets::FormComponent.new(campaign: @campaign, scene: @scene, scene_secret: @scene_secret),
               status: :unprocessable_content
      end
    end

    def destroy
      @scene_secret.destroy!
      redirect_to admin_campaign_scene_scene_secrets_path(@campaign, @scene), notice: "Scene secret removed."
    end

    private

    def load_campaign_and_scene
      @campaign = current_user.campaigns.find(params[:campaign_id])
      @scene = @campaign.scenes.find(params[:scene_id])
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    def load_scene_secret
      @scene_secret = @scene.scene_secrets.find(params[:id])
    end

    def scene_secret_params
      params.require(:scene_secret).permit(:label, :content)
    end
  end
end
