module Admin
  module Campaigns
    class IndexComponent < ViewComponent::Base
      def initialize(campaigns:)
        @campaigns = campaigns
      end

      attr_reader :campaigns
    end
  end
end
