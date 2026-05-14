FactoryBot.define do
  factory :npc_secret do
    npc
    sequence(:label) { |n| "Hidden NPC fact #{n}" }
    content { "This is hidden content the player must not see." }
  end
end
