# == Schema Information
#
# Table name: npc_secrets
#
#  id         :bigint           not null, primary key
#  content    :text             not null
#  label      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  npc_id     :bigint           not null
#
# Indexes
#
#  index_npc_secrets_on_npc_id  (npc_id)
#
# Foreign Keys
#
#  fk_rails_...  (npc_id => npcs.id) ON DELETE => cascade
#
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
