module Play
  module Roster
    class SidebarComponent < ViewComponent::Base
      def initialize(scene:)
        @scene = scene
        @state = Player::SceneStateViewModel.new(scene)
      end
      attr_reader :scene, :state

      def pcs        = scene.campaign.player_characters.pcs.order(:name).map { Player::PlayerCharacterViewModel.new(_1) }
      def companions = scene.campaign.player_characters.companions.order(:name).map { Player::PlayerCharacterViewModel.new(_1) }
      def main_id    = scene.campaign.main_character_id
      def declared_ids = state.declared_this_turn.map(&:id)
    end
  end
end
