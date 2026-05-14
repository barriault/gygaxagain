class CreateNpcs < ActiveRecord::Migration[8.1]
  def change
    create_table :npcs do |t|
      t.references :campaign, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.text :public_description
      t.string :location
      t.timestamps
    end
  end
end
