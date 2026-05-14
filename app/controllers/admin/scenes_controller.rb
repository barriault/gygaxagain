module Admin
  class ScenesController < Admin::ApplicationController
    before_action :load_campaign
    before_action :load_scene, only: [ :edit, :update, :destroy, :move_up, :move_down ]

    def index
      redirect_to admin_campaign_path(@campaign)
    end

    def new
      @scene = @campaign.scenes.build
      render Admin::Scenes::FormComponent.new(campaign: @campaign, scene: @scene)
    end

    def create
      @scene = @campaign.scenes.build(scene_params)
      if @scene.save
        redirect_to admin_campaign_path(@campaign), notice: "Scene created."
      else
        render Admin::Scenes::FormComponent.new(campaign: @campaign, scene: @scene),
               status: :unprocessable_entity
      end
    end

    def edit
      render Admin::Scenes::FormComponent.new(campaign: @campaign, scene: @scene)
    end

    def update
      if @scene.update(scene_params)
        redirect_to admin_campaign_path(@campaign), notice: "Scene updated."
      else
        render Admin::Scenes::FormComponent.new(campaign: @campaign, scene: @scene),
               status: :unprocessable_entity
      end
    end

    def destroy
      @scene.destroy
      redirect_to admin_campaign_path(@campaign), notice: "Scene deleted."
    end

    def move_up
      @scene.move_higher
      redirect_to admin_campaign_path(@campaign)
    end

    def move_down
      @scene.move_lower
      redirect_to admin_campaign_path(@campaign)
    end

    private

    def load_campaign
      @campaign = current_user.campaigns.find(params[:campaign_id])
    end

    def load_scene
      @scene = @campaign.scenes.find(params[:id])
    end

    def scene_params
      params.require(:scene).permit(:title, :summary)
    end
  end
end
