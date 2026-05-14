class CreateSceneAudits < ActiveRecord::Migration[8.1]
  def change
    create_table :scene_audits do |t|
      t.references :scene,    null: false, foreign_key: { on_delete: :cascade },  index: { unique: true }
      t.references :llm_call, null: false, foreign_key: { on_delete: :restrict }
      t.string :verdict, null: false
      t.jsonb  :result,  null: false, default: {}
      t.timestamps
    end

    add_index :scene_audits, :verdict
  end
end
