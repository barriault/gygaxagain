# == Schema Information
#
# Table name: campaigns
#
#  id                :bigint           not null, primary key
#  chaos_factor      :integer          default(5), not null
#  description       :text
#  name              :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  main_character_id :bigint
#  user_id           :bigint           not null
#
# Indexes
#
#  index_campaigns_on_main_character_id       (main_character_id)
#  index_campaigns_on_user_id                 (user_id)
#  index_campaigns_on_user_id_and_lower_name  (user_id, lower((name)::text)) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (main_character_id => player_characters.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :campaign do
    user
    sequence(:name) { |n| "Campaign #{n}" }
  end
end
