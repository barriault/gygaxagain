# == Schema Information
#
# Table name: campaigns
#
#  id          :bigint           not null, primary key
#  description :text
#  name        :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  user_id     :bigint           not null
#
# Indexes
#
#  index_campaigns_on_user_id           (user_id)
#  index_campaigns_on_user_id_and_name  (user_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe Campaign, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    subject { build(:campaign) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }

    it "validates uniqueness of name scoped to user" do
      user = create(:user)
      create(:campaign, user: user, name: "Strahd")
      duplicate = build(:campaign, user: user, name: "Strahd")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include("has already been taken")
    end

    it "allows two users to have campaigns with the same name" do
      user_a = create(:user)
      user_b = create(:user)
      create(:campaign, user: user_a, name: "Strahd")
      expect(build(:campaign, user: user_b, name: "Strahd")).to be_valid
    end

    it "treats name uniqueness as case-insensitive within a user" do
      user = create(:user)
      create(:campaign, user: user, name: "Strahd")
      duplicate = build(:campaign, user: user, name: "strahd")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include("has already been taken")
    end
  end

  describe "factory" do
    it "creates a persistable campaign" do
      campaign = build(:campaign)
      expect(campaign).to be_valid
      expect { campaign.save! }.not_to raise_error
    end
  end
end
