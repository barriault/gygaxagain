class CreateSceneSecrets < ActiveRecord::Migration[8.1]
  def change
    create_table :scene_secrets do |t|
      t.references :scene, null: false, foreign_key: { on_delete: :cascade }
      t.string :label,   null: false
      t.text   :content, null: false
      t.timestamps
    end

    add_index :scene_secrets, "scene_id, lower((label)::text)", unique: true,
              name: "index_scene_secrets_on_scene_and_label"
  end
end
