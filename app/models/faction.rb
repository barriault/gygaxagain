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
class Faction < ApplicationRecord
  belongs_to :campaign
  has_many :secrets, class_name: "FactionSecret", dependent: :destroy

  validates :name, presence: true,
                   length: { maximum: 100 },
                   uniqueness: { scope: :campaign_id, case_sensitive: false }
end
