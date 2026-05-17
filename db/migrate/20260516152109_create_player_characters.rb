class CreatePlayerCharacters < ActiveRecord::Migration[8.1]
  def change
    create_table :player_characters do |t|
      t.references :campaign, null: false, foreign_key: { on_delete: :cascade }
      t.string  :name,       null: false
      t.string  :pronouns
      t.string  :class_name
      t.integer :level
      t.string  :role,       null: false, default: "pc"
      t.text    :notes
      t.timestamps
    end

    add_index :player_characters, [ :campaign_id, :name ], unique: true,
              name: "index_player_characters_on_campaign_and_name"
  end
end
