require "rails_helper"

RSpec.describe NpcSecret, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:npc) }
  end

  describe "validations" do
    subject { build(:npc_secret) }

    it { is_expected.to validate_presence_of(:label) }
    it { is_expected.to validate_length_of(:label).is_at_most(100) }
    it { is_expected.to validate_presence_of(:content) }
  end

  describe "cascade on npc delete" do
    it "removes npc_secrets when their npc is deleted at the DB level" do
      npc = create(:npc)
      secret = create(:npc_secret, npc: npc)
      ActiveRecord::Base.connection.execute("DELETE FROM npcs WHERE id = #{npc.id}")
      expect(NpcSecret.where(id: secret.id)).to be_empty
    end
  end
end
