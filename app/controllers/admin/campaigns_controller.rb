module Admin
  class CampaignsController < ::ApplicationController
    def index
      @campaigns = current_user.campaigns.order(:name)
      render Admin::Campaigns::IndexComponent.new(campaigns: @campaigns)
    end
  end
end
