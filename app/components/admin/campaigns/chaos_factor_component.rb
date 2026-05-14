module Admin
  module Campaigns
    class ChaosFactorComponent < ViewComponent::Base
      def initialize(campaign:)
        @campaign = campaign
      end

      attr_reader :campaign

      def at_floor?
        campaign.chaos_factor <= 1
      end

      def at_ceiling?
        campaign.chaos_factor >= 9
      end
    end
  end
end
