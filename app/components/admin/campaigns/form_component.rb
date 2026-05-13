module Admin
  module Campaigns
    class FormComponent < ViewComponent::Base
      def initialize(campaign:, form_url:, method:)
        @campaign = campaign
        @form_url = form_url
        @method = method
      end

      attr_reader :campaign, :form_url, :method
    end
  end
end
