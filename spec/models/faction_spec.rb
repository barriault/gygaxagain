# == Schema Information
#
# Table name: factions
#
#  id                 :bigint           not null, primary key
#  name               :string           not null
#  public_description :text
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  campaign_id        :bigint           not null
#
# Indexes
#
#  index_factions_on_campaign_id                 (campaign_id)
#  index_factions_on_campaign_id_and_lower_name  (campaign_id, lower((name)::text)) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (campaign_id => campaigns.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe Faction, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:campaign) }
  end

  describe "validations" do
    subject { build(:faction) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:campaign_id).case_insensitive }
  end

  describe "cascade on campaign delete" do
    it "removes factions when their campaign is deleted at the DB level" do
      campaign = create(:campaign)
      faction = create(:faction, campaign: campaign)
      ActiveRecord::Base.connection.execute("DELETE FROM campaigns WHERE id = #{campaign.id}")
      expect(Faction.where(id: faction.id)).to be_empty
    end
  end
end
