class AddLastPlayedCampaignIdToUsers < ActiveRecord::Migration[8.1]
  def change
    add_reference :users, :last_played_campaign,
                  foreign_key: { to_table: :campaigns, on_delete: :nullify },
                  null: true,
                  index: true
  end
end
