module Admin
  module Campaigns
    class ChaosFactorComponentPreview < ViewComponent::Preview
      def mid_range
        campaign = Campaign.new(id: 1, name: "Preview", chaos_factor: 5)
        render Admin::Campaigns::ChaosFactorComponent.new(campaign: campaign)
      end

      def at_minimum
        campaign = Campaign.new(id: 1, name: "Preview", chaos_factor: 1)
        render Admin::Campaigns::ChaosFactorComponent.new(campaign: campaign)
      end

      def at_maximum
        campaign = Campaign.new(id: 1, name: "Preview", chaos_factor: 9)
        render Admin::Campaigns::ChaosFactorComponent.new(campaign: campaign)
      end
    end
  end
end
