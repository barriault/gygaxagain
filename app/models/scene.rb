# == Schema Information
#
# Table name: scenes
#
#  id          :bigint           not null, primary key
#  closed_at   :datetime
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
#  index_scenes_on_closed_at                 (closed_at)
#
# Foreign Keys
#
#  fk_rails_...  (campaign_id => campaigns.id) ON DELETE => cascade
#
class Scene < ApplicationRecord
  belongs_to :campaign
  has_many :events, dependent: :destroy
  has_many :llm_calls, dependent: :nullify
  has_one :audit, class_name: "SceneAudit", dependent: :destroy

  acts_as_list scope: :campaign

  validates :title, presence: true, length: { maximum: 100 }

  def closed?
    closed_at.present?
  end
end
