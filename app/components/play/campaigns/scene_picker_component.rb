module Play
  module Campaigns
    class ScenePickerComponent < ViewComponent::Base
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
