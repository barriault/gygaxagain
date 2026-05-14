class AddChaosFactorToCampaigns < ActiveRecord::Migration[8.1]
  def change
    add_column :campaigns, :chaos_factor, :integer, default: 5, null: false
  end
end
