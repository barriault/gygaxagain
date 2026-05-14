class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.references :scene, null: false, foreign_key: { on_delete: :cascade }
      t.string :kind, null: false
      t.jsonb :payload, null: false, default: {}
      t.datetime :occurred_at, null: false
      t.timestamps
    end

    add_index :events, [:scene_id, :occurred_at]
    add_index :events, :kind
  end
end
