module Admin
  module PlayerCharacters
    class RowComponent < ViewComponent::Base
      def initialize(campaign:, player_character:)
        @campaign = campaign
        @pc = player_character
      end

      attr_reader :campaign, :pc
    end
  end
end
