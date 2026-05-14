class CreateCampaigns < ActiveRecord::Migration[8.1]
  def change
    create_table :campaigns do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.text :description

      t.timestamps
    end

    add_index :campaigns, [ :user_id, :name ], unique: true
  end
end
