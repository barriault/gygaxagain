class AddPcAndTurnToEvents < ActiveRecord::Migration[8.1]
  def change
    add_reference :events, :pc,
                  null: true,
                  foreign_key: { to_table: :player_characters, on_delete: :nullify }
    add_column :events, :turn_number, :integer
    add_index  :events, [ :scene_id, :turn_number ]
  end
end
