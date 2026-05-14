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
