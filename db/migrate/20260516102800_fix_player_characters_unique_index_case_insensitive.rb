class FixPlayerCharactersUniqueIndexCaseInsensitive < ActiveRecord::Migration[8.1]
  def up
    remove_index :player_characters, name: "index_player_characters_on_campaign_and_name"
    add_index :player_characters, "campaign_id, lower((name)::text)", unique: true,
              name: "index_player_characters_on_campaign_and_name"
  end

  def down
    remove_index :player_characters, name: "index_player_characters_on_campaign_and_name"
    add_index :player_characters, [ :campaign_id, :name ], unique: true,
              name: "index_player_characters_on_campaign_and_name"
  end
end
