# == Schema Information
#
# Table name: events
#
#  id          :bigint           not null, primary key
#  kind        :string           not null
#  occurred_at :datetime         not null
#  payload     :jsonb            not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  scene_id    :bigint           not null
#
# Indexes
#
#  index_events_on_kind                      (kind)
#  index_events_on_scene_id                  (scene_id)
#  index_events_on_scene_id_and_occurred_at  (scene_id,occurred_at)
#
# Foreign Keys
#
#  fk_rails_...  (scene_id => scenes.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :event do
    scene
    kind { "narration" }
    payload { { text: "Some narration." } }

    trait :dice_roll do
      kind { "dice_roll" }
      payload { { expression: "2d6+3", result: 10, breakdown: [ 4, 3, "+3" ] } }
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
