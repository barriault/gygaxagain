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
#  index_player_characters_on_campaign_and_name  (campaign_id,name) UNIQUE
#  index_player_characters_on_campaign_id        (campaign_id)
#
# Foreign Keys
#
#  fk_rails_...  (campaign_id => campaigns.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :player_character do
    campaign
    sequence(:name) { |n| "Hero #{n}" }
    pronouns       { "they/them" }
    class_name     { "Fighter" }
    level          { 1 }
    role           { "pc" }
    notes          { nil }
  end
end
