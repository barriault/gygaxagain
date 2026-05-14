module Play
  class CampaignsController < ::ApplicationController
    def index
      @campaigns = current_user.campaigns.order(:name)
      render Play::Campaigns::PickerComponent.new(campaigns: @campaigns)
    end

    def play
      @campaign = current_user.campaigns.find(params[:id])
      current_user.update_column(:last_played_campaign_id, @campaign.id)

      if @campaign.scenes.any?
        render Play::Campaigns::ScenePickerComponent.new(campaign: @campaign)
      else
        render Play::Campaigns::PlaceholderComponent.new(campaign: @campaign)
      end
    end
  end
end
