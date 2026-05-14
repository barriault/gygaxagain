# == Schema Information
#
# Table name: npcs
#
#  id                 :bigint           not null, primary key
#  location           :string
#  name               :string           not null
#  public_description :text
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  campaign_id        :bigint           not null
#
# Indexes
#
#  index_npcs_on_campaign_id  (campaign_id)
#
# Foreign Keys
#
#  fk_rails_...  (campaign_id => campaigns.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :npc do
    campaign
    sequence(:name) { |n| "NPC #{n}" }
    public_description { "A public-facing description." }
    location { "Somewhere visible" }

    trait :with_secrets do
      after(:create) do |npc|
        create_list(:npc_secret, 2, npc: npc)
      end
    end
  end
end
