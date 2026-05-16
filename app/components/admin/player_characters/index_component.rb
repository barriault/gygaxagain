module Admin
  module PlayerCharacters
    class IndexComponent < ViewComponent::Base
      def initialize(campaign:, player_characters:)
        @campaign = campaign
        @player_characters = player_characters
      end

      attr_reader :campaign, :player_characters
    end
  end
end
