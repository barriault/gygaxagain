module Admin
  module Campaigns
    class ShowComponent < ViewComponent::Base
      def initialize(campaign:)
        @campaign = campaign
      end

      attr_reader :campaign

      def scenes
        @scenes ||= campaign.scenes.order(:position)
      end
    end
  end
end
