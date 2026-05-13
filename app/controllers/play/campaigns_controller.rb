module Play
  class CampaignsController < ::ApplicationController
    def index
      @campaigns = current_user.campaigns.order(:name)
      render Play::Campaigns::PickerComponent.new(campaigns: @campaigns)
    end
  end
end
