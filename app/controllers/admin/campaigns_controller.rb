module Admin
  class CampaignsController < Admin::ApplicationController
    before_action :load_campaign, only: [ :show, :edit, :update, :destroy ]

    def index
      @campaigns = current_user.campaigns.order(:name)
      render Admin::Campaigns::IndexComponent.new(campaigns: @campaigns)
    end

    def show
      render Admin::Campaigns::ShowComponent.new(campaign: @campaign)
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

    def edit
      render Admin::Campaigns::FormComponent.new(
        campaign: @campaign,
        form_url: admin_campaign_path(@campaign),
        method: :patch
      )
    end

    def update
      if @campaign.update(campaign_params)
        redirect_to admin_campaigns_path, notice: "Campaign updated."
      else
        render Admin::Campaigns::FormComponent.new(
          campaign: @campaign,
          form_url: admin_campaign_path(@campaign),
          method: :patch
        ), status: :unprocessable_entity
      end
    end

    def destroy
      @campaign.destroy
      redirect_to admin_campaigns_path, notice: "Campaign deleted."
    end

    private

    def load_campaign
      @campaign = current_user.campaigns.find(params[:id])
    end

    def campaign_params
      params.require(:campaign).permit(:name, :description, :main_character_id)
    end
  end
end
