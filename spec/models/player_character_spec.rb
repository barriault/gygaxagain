# == Schema Information
#
# Table name: player_characters
#
#  id          :bigint           not null, primary key
#  class_name  :string
#  level       :integer
#  name        :string           not null
#  notes       :text
#  pronouns    :string
#  role        :string           default("pc"), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  campaign_id :bigint           not null
#
# Indexes
#
#  index_player_characters_on_campaign_and_name  (campaign_id,name) UNIQUE
#  index_player_characters_on_campaign_id        (campaign_id)
#
# Foreign Keys
#
#  fk_rails_...  (campaign_id => campaigns.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe PlayerCharacter, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:campaign) }
  end

  describe "validations" do
    subject { build(:player_character) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:campaign_id).case_insensitive }
  end

  describe "role enum" do
    it "exposes pc? and companion? predicates" do
      expect(build(:player_character, role: "pc")).to be_pc
      expect(build(:player_character, role: "companion")).to be_companion
    end

    it "defaults role to pc when unset" do
      expect(PlayerCharacter.new.role).to eq("pc")
    end

    it "rejects unknown roles" do
      expect { build(:player_character, role: "boss") }.to raise_error(ArgumentError)
    end
  end

  describe "scopes" do
    let(:campaign) { create(:campaign) }
    let!(:pc)        { create(:player_character, campaign:, role: "pc",        name: "Aragorn") }
    let!(:companion) { create(:player_character, campaign:, role: "companion", name: "Caine") }

    it ".pcs returns only PCs" do
      expect(campaign.player_characters.pcs).to contain_exactly(pc)
    end

    it ".companions returns only companions" do
      expect(campaign.player_characters.companions).to contain_exactly(companion)
    end
  end
end
