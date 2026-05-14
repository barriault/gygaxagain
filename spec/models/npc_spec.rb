# == Schema Information
#
# Table name: npcs
#
#  id                 :bigint           not null, primary key
#  location           :string
#  name               :string           not null
#  public_description :text
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  campaign_id        :bigint           not null
#
# Indexes
#
#  index_npcs_on_campaign_id  (campaign_id)
#
# Foreign Keys
#
#  fk_rails_...  (campaign_id => campaigns.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe Npc, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:campaign) }
  end

  describe "validations" do
    subject { build(:npc) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }
  end

  describe "name uniqueness" do
    it "does NOT enforce per-campaign uniqueness on name" do
      campaign = create(:campaign)
      create(:npc, campaign: campaign, name: "John")
      duplicate = build(:npc, campaign: campaign, name: "John")
      expect(duplicate).to be_valid
    end
  end

  describe "cascade on campaign delete" do
    it "removes npcs when their campaign is deleted at the DB level" do
      campaign = create(:campaign)
      npc = create(:npc, campaign: campaign)
      ActiveRecord::Base.connection.execute("DELETE FROM campaigns WHERE id = #{campaign.id}")
      expect(Npc.where(id: npc.id)).to be_empty
    end
  end
end
