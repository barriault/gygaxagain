class CreateFactionSecrets < ActiveRecord::Migration[8.1]
  def change
    create_table :faction_secrets do |t|
      t.references :faction, null: false, foreign_key: { on_delete: :cascade }
      t.string :label, null: false
      t.text :content, null: false
      t.timestamps
    end
  end
end
