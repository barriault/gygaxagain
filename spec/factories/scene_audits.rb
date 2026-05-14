# == Schema Information
#
# Table name: scene_audits
#
#  id          :bigint           not null, primary key
#  result      :jsonb            not null
#  verdict     :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  llm_call_id :bigint           not null
#  scene_id    :bigint           not null
#
# Indexes
#
#  index_scene_audits_on_llm_call_id  (llm_call_id)
#  index_scene_audits_on_scene_id     (scene_id) UNIQUE
#  index_scene_audits_on_verdict      (verdict)
#
# Foreign Keys
#
#  fk_rails_...  (llm_call_id => llm_calls.id) ON DELETE => restrict
#  fk_rails_...  (scene_id => scenes.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :scene_audit do
    scene
    association :llm_call, factory: :llm_call
    verdict { "pass" }
    result {
      {
        "verdict" => "pass",
        "criteria" => [
          { "name" => "player_agency",            "status" => "pass", "note" => "..." },
          { "name" => "follow_through",           "status" => "pass", "note" => "..." },
          { "name" => "over_narration_of_intent", "status" => "pass", "note" => "..." },
          { "name" => "mechanical_handoff",       "status" => "pass", "note" => "..." }
        ],
        "summary" => "Looks good."
      }
    }

    trait :concerns do
      verdict { "concerns" }
      result {
        { "verdict" => "concerns",
          "criteria" => [{ "name" => "player_agency", "status" => "concerns", "note" => "..." }],
          "summary" => "Some concerns." }
      }
    end

    trait :failed do
      verdict { "fail" }
      result { { "verdict" => "fail", "summary" => "Bad." } }
    end
  end
end
