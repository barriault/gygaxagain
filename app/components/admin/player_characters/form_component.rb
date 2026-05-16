module Admin
  module PlayerCharacters
    class FormComponent < ViewComponent::Base
      def initialize(campaign:, player_character:)
        @campaign = campaign
        @pc = player_character
      end

      attr_reader :campaign, :pc

      def form_url
        if pc.persisted?
          admin_campaign_player_character_path(campaign, pc)
        else
          admin_campaign_player_characters_path(campaign)
        end
      end

      def form_method = pc.persisted? ? :patch : :post
      def heading     = pc.persisted? ? "Edit #{pc.name}" : "New PC"
      def submit      = pc.persisted? ? "Save" : "Create"
    end
  end
end
