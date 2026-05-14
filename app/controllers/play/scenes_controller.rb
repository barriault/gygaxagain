module Play
  class ScenesController < ::ApplicationController
    def play
      @scene = current_user
                 .campaigns
                 .find(params[:campaign_id])
                 .scenes
                 .find(params[:id])

      render Play::Scenes::PlayComponent.new(scene: @scene)
    end
  end
end
