class AddMainCharacterToCampaigns < ActiveRecord::Migration[8.1]
  def change
    add_reference :campaigns, :main_character,
                  null: true,
                  foreign_key: { to_table: :player_characters, on_delete: :nullify }
  end
end
