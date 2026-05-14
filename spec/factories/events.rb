FactoryBot.define do
  factory :event do
    scene
    kind { "narration" }
    payload { { text: "Some narration." } }

    trait :dice_roll do
      kind { "dice_roll" }
      payload { { expression: "2d6+3", result: 10, breakdown: [4, 3, "+3"] } }
    end

    trait :oracle_query do
      kind { "oracle_query" }
      payload { { question: "Is it raining?", likelihood: "even_odds", chaos: 5, answer: "yes" } }
    end

    trait :scene_transition do
      kind { "scene_transition" }
      payload { { from_scene_id: nil, to_scene_id: nil, reason: "Player chose to leave." } }
    end
  end
end
