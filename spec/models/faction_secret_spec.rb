require "rails_helper"

RSpec.describe FactionSecret, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:faction) }
  end

  describe "validations" do
    subject { build(:faction_secret) }

    it { is_expected.to validate_presence_of(:label) }
    it { is_expected.to validate_length_of(:label).is_at_most(100) }
    it { is_expected.to validate_presence_of(:content) }
  end

  describe "cascade on faction delete" do
    it "removes faction_secrets when their faction is deleted at the DB level" do
      faction = create(:faction)
      secret = create(:faction_secret, faction: faction)
      ActiveRecord::Base.connection.execute("DELETE FROM factions WHERE id = #{faction.id}")
      expect(FactionSecret.where(id: secret.id)).to be_empty
    end
  end
end
