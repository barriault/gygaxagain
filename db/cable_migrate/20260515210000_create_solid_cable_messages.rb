class CreateSolidCableMessages < ActiveRecord::Migration[7.1]
  def up
    # Drop first in case an earlier deploy left a partial / broken table
    # (this is what the production "ArgumentError: No unique index found
    # for id" symptom indicates). Safe: solid_cable_messages is ephemeral
    # broadcast state, not durable application data.
    drop_table :solid_cable_messages, if_exists: true

    create_table :solid_cable_messages do |t|
      t.binary :channel, limit: 1024, null: false
      t.binary :payload, limit: 536_870_912, null: false
      t.datetime :created_at, null: false
      t.integer :channel_hash, limit: 8, null: false

      t.index :channel
      t.index :channel_hash
      t.index :created_at
    end
  end

  def down
    drop_table :solid_cable_messages, if_exists: true
  end
end
