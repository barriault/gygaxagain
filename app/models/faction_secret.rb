# == Schema Information
#
# Table name: faction_secrets
#
#  id         :bigint           not null, primary key
#  content    :text             not null
#  label      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  faction_id :bigint           not null
#
# Indexes
#
#  index_faction_secrets_on_faction_id  (faction_id)
#
# Foreign Keys
#
#  fk_rails_...  (faction_id => factions.id) ON DELETE => cascade
#
class FactionSecret < ApplicationRecord
  belongs_to :faction

  validates :label,   presence: true, length: { maximum: 100 }
  validates :content, presence: true
end
