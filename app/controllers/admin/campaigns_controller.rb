module Admin
  class CampaignsController < ::ApplicationController
    def index
      @campaigns = current_user.campaigns.order(:name)
      render Admin::Campaigns::IndexComponent.new(campaigns: @campaigns)
    end

    def new
      @campaign = current_user.campaigns.build
      render Admin::Campaigns::FormComponent.new(
        campaign: @campaign,
        form_url: admin_campaigns_path,
        method: :post
      )
    end

    def create
      @campaign = current_user.campaigns.build(campaign_params)
      if @campaign.save
        redirect_to admin_campaigns_path, notice: "Campaign created."
      else
        render Admin::Campaigns::FormComponent.new(
          campaign: @campaign,
          form_url: admin_campaigns_path,
          method: :post
        ), status: :unprocessable_entity
      end
    end

    private

    def campaign_params
      params.require(:campaign).permit(:name, :description)
    end
  end
end
