# == Schema Information
#
# Table name: campaigns
#
#  id           :bigint           not null, primary key
#  chaos_factor :integer          default(5), not null
#  description  :text
#  name         :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  user_id      :bigint           not null
#
# Indexes
#
#  index_campaigns_on_user_id                 (user_id)
#  index_campaigns_on_user_id_and_lower_name  (user_id, lower((name)::text)) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class Campaign < ApplicationRecord
  belongs_to :user
  has_many :llm_calls, dependent: :destroy
  has_many :factions, dependent: :destroy
  has_many :npcs, dependent: :destroy
  has_many :scenes, dependent: :destroy
  has_many :scene_audits, through: :scenes, source: :audit

  validates :name, presence: true,
                   length: { maximum: 100 },
                   uniqueness: { scope: :user_id, case_sensitive: false }

  validates :chaos_factor, presence: true,
                           numericality: { only_integer: true,
                                           greater_than_or_equal_to: 1,
                                           less_than_or_equal_to: 9 }
end
