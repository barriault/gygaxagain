class CreateScenes < ActiveRecord::Migration[8.1]
  def change
    create_table :scenes do |t|
      t.references :campaign, null: false, foreign_key: { on_delete: :cascade }
      t.string :title, null: false
      t.text :summary
      t.integer :position, null: false
      t.timestamps
    end

    add_index :scenes, [ :campaign_id, :position ]
  end
end
