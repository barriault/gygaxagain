module Admin
  class PlayerCharactersController < Admin::ApplicationController
    before_action :load_campaign
    before_action :load_player_character, only: %i[show edit update destroy]

    def index
      pcs = @campaign.player_characters.order(:name)
      render Admin::PlayerCharacters::IndexComponent.new(campaign: @campaign, player_characters: pcs)
    end

    def show
      render Admin::PlayerCharacters::ShowComponent.new(campaign: @campaign, player_character: @player_character)
    end

    def new
      @player_character = @campaign.player_characters.new(role: "pc")
      render Admin::PlayerCharacters::FormComponent.new(campaign: @campaign, player_character: @player_character)
    end

    def create
      @player_character = @campaign.player_characters.new(player_character_params)
      if @player_character.save
        redirect_to admin_campaign_player_characters_path(@campaign), notice: "PC created."
      else
        render Admin::PlayerCharacters::FormComponent.new(campaign: @campaign, player_character: @player_character),
               status: :unprocessable_content
      end
    end

    def edit
      render Admin::PlayerCharacters::FormComponent.new(campaign: @campaign, player_character: @player_character)
    end

    def update
      if @player_character.update(player_character_params)
        redirect_to admin_campaign_player_characters_path(@campaign), notice: "PC updated."
      else
        render Admin::PlayerCharacters::FormComponent.new(campaign: @campaign, player_character: @player_character),
               status: :unprocessable_content
      end
    end

    def destroy
      @player_character.destroy!
      redirect_to admin_campaign_player_characters_path(@campaign), notice: "PC removed."
    end

    private

    def load_campaign
      @campaign = current_user.campaigns.find(params[:campaign_id])
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    def load_player_character
      @player_character = @campaign.player_characters.find(params[:id])
    end

    def player_character_params
      params.require(:player_character).permit(:name, :pronouns, :class_name, :level, :role, :notes)
    end
  end
end
