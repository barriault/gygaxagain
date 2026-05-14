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
FactoryBot.define do
  factory :scene do
    campaign
    sequence(:title) { |n| "Scene #{n}" }
    summary { "A short scene summary." }
    # position auto-assigned by acts_as_list
  end
end
