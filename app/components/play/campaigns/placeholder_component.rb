module Play
  module Campaigns
    class PlaceholderComponent < ViewComponent::Base
      def initialize(campaign:)
        @campaign = campaign
      end

      attr_reader :campaign
    end
  end
end
