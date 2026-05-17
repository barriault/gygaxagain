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
#  index_player_characters_on_campaign_and_name  (campaign_id, lower((name)::text)) UNIQUE
#  index_player_characters_on_campaign_id        (campaign_id)
#
# Foreign Keys
#
#  fk_rails_...  (campaign_id => campaigns.id) ON DELETE => cascade
#
class PlayerCharacter < ApplicationRecord
  ROLES = %w[pc companion].freeze

  belongs_to :campaign

  enum :role, ROLES.index_with(&:itself)

  validates :name, presence: true,
                   uniqueness: { scope: :campaign_id, case_sensitive: false }

  scope :pcs,        -> { where(role: "pc") }
  scope :companions, -> { where(role: "companion") }
end
