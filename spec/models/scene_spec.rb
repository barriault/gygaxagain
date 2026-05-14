# == Schema Information
#
# Table name: scenes
#
#  id          :bigint           not null, primary key
#  position    :integer          not null
#  summary     :text
#  title       :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  campaign_id :bigint           not null
#
# Indexes
#
#  index_scenes_on_campaign_id               (campaign_id)
#  index_scenes_on_campaign_id_and_position  (campaign_id,position)
#
# Foreign Keys
#
#  fk_rails_...  (campaign_id => campaigns.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe Scene, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:campaign) }
    it { is_expected.to have_many(:events).dependent(:destroy) }
    it { is_expected.to have_many(:llm_calls).dependent(:nullify) }
  end

  describe "validations" do
    subject { build(:scene) }

    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_length_of(:title).is_at_most(100) }
  end

  describe "acts_as_list ordering" do
    let(:campaign) { create(:campaign) }
    let!(:first)   { create(:scene, campaign: campaign, title: "First") }
    let!(:second)  { create(:scene, campaign: campaign, title: "Second") }
    let!(:third)   { create(:scene, campaign: campaign, title: "Third") }

    it "auto-assigns sequential positions within a campaign" do
      expect([ first.reload.position, second.reload.position, third.reload.position ]).to eq([ 1, 2, 3 ])
    end

    it "scopes positions to the campaign (a second campaign's scenes restart at 1)" do
      other_campaign = create(:campaign)
      other_scene = create(:scene, campaign: other_campaign)
      expect(other_scene.reload.position).to eq(1)
    end

    it "reorders via move_higher!" do
      third.move_higher
      expect([ first.reload.position, second.reload.position, third.reload.position ]).to eq([ 1, 3, 2 ])
    end

    it "first? and last? report position correctly" do
      expect(first.reload).to be_first
      expect(third.reload).to be_last
    end
  end

  describe "cascade on campaign delete" do
    it "removes scenes when their campaign is deleted at the DB level" do
      campaign = create(:campaign)
      scene = create(:scene, campaign: campaign)
      ActiveRecord::Base.connection.execute("DELETE FROM campaigns WHERE id = #{campaign.id}")
      expect(Scene.where(id: scene.id)).to be_empty
    end
  end
end
