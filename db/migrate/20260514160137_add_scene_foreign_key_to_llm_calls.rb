class AddSceneForeignKeyToLlmCalls < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :llm_calls, :scenes, on_delete: :nullify
  end
end
