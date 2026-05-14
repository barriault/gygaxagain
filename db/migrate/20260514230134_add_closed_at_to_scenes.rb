class AddClosedAtToScenes < ActiveRecord::Migration[8.1]
  def change
    add_column :scenes, :closed_at, :datetime, null: true
    add_index  :scenes, :closed_at
  end
end
