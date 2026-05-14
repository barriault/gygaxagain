class CreateFactions < ActiveRecord::Migration[8.1]
  def change
    create_table :factions do |t|
      t.references :campaign, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.text :public_description
      t.timestamps
    end

    add_index :factions, "campaign_id, lower(name)",
              unique: true,
              name: "index_factions_on_campaign_id_and_lower_name"
  end
end
