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
FactoryBot.define do
  factory :faction do
    campaign
    sequence(:name) { |n| "Faction #{n}" }
    public_description { "A public-facing description." }

    trait :with_secrets do
      after(:create) do |faction|
        create_list(:faction_secret, 2, faction: faction)
      end
    end
  end
end
