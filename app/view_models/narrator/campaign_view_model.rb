module Narrator
  class CampaignViewModel < ApplicationViewModel
    expose :name
    expose :description

    expose :factions do
      @record.factions.order(:name).map { Narrator::FactionViewModel.new(_1) }
    end

    expose :npcs do
      @record.npcs.order(:name).map { Narrator::NpcViewModel.new(_1) }
    end

    expose :pcs do
      @record.player_characters.pcs.order(:name).map { Narrator::PlayerCharacterViewModel.new(_1) }
    end

    expose :companions do
      @record.player_characters.companions.order(:name).map { Narrator::PlayerCharacterViewModel.new(_1) }
    end

    expose :main_character do
      return nil unless @record.main_character
      Narrator::PlayerCharacterViewModel.new(@record.main_character)
    end
  end
end
