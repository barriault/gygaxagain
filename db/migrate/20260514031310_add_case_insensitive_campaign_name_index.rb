class AddCaseInsensitiveCampaignNameIndex < ActiveRecord::Migration[8.1]
  def change
    remove_index :campaigns, [:user_id, :name], unique: true
    add_index :campaigns,
              "user_id, LOWER(name)",
              unique: true,
              name: "index_campaigns_on_user_id_and_lower_name"
  end
end
