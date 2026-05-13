module Play
  module Campaigns
    class PickerComponent < ViewComponent::Base
      def initialize(campaigns:)
        @campaigns = campaigns
      end

      attr_reader :campaigns
    end
  end
end
