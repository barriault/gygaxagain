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
