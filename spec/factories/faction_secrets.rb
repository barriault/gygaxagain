FactoryBot.define do
  factory :faction_secret do
    faction
    sequence(:label) { |n| "Hidden fact #{n}" }
    content { "This is hidden content the player must not see." }
  end
end
