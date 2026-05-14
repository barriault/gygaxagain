class CreateLlmCalls < ActiveRecord::Migration[8.1]
  def change
    create_table :llm_calls do |t|
      t.references :user,     null: false, foreign_key: { on_delete: :cascade }
      t.references :campaign, null: true,  foreign_key: { on_delete: :cascade }
      t.references :scene,    null: true,  index: true
      t.string  :purpose,                  null: false
      t.string  :provider,                 null: false
      t.string  :model,                    null: false
      t.integer :input_tokens,             null: false, default: 0
      t.integer :output_tokens,            null: false, default: 0
      t.integer :cache_creation_tokens,    null: false, default: 0
      t.integer :cache_read_tokens,        null: false, default: 0
      t.integer :total_cost_cents,         null: false, default: 0
      t.integer :latency_ms
      t.string  :provider_request_id
      t.jsonb   :prompt_payload,           null: false, default: {}
      t.jsonb   :response_payload,         null: false, default: {}

      t.timestamps
    end

    add_index :llm_calls, [ :purpose, :created_at ]
    add_index :llm_calls, [ :provider, :model ]
  end
end
