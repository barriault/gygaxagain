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
FactoryBot.define do
  factory :faction_secret do
    faction
    sequence(:label) { |n| "Hidden fact #{n}" }
    content { "This is hidden content the player must not see." }
  end
end
