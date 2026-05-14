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
class Npc < ApplicationRecord
  belongs_to :campaign
  has_many :secrets, class_name: "NpcSecret", dependent: :destroy

  validates :name, presence: true, length: { maximum: 100 }
end
