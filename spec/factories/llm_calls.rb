# == Schema Information
#
# Table name: llm_calls
#
#  id                    :bigint           not null, primary key
#  cache_creation_tokens :integer          default(0), not null
#  cache_read_tokens     :integer          default(0), not null
#  input_tokens          :integer          default(0), not null
#  latency_ms            :integer
#  model                 :string           not null
#  output_tokens         :integer          default(0), not null
#  prompt_payload        :jsonb            not null
#  provider              :string           not null
#  purpose               :string           not null
#  response_payload      :jsonb            not null
#  total_cost_cents      :integer          default(0), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  campaign_id           :bigint
#  provider_request_id   :string
#  scene_id              :bigint
#  user_id               :bigint           not null
#
# Indexes
#
#  index_llm_calls_on_campaign_id             (campaign_id)
#  index_llm_calls_on_provider_and_model      (provider,model)
#  index_llm_calls_on_purpose_and_created_at  (purpose,created_at)
#  index_llm_calls_on_scene_id                (scene_id)
#  index_llm_calls_on_user_id                 (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (campaign_id => campaigns.id) ON DELETE => cascade
#  fk_rails_...  (scene_id => scenes.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :llm_call do
    user
    purpose  { "diagnostics" }
    provider { "anthropic" }
    model    { "claude-sonnet-4-6" }
    input_tokens     { 100 }
    output_tokens    { 50 }
    total_cost_cents { 105 }
    latency_ms       { 1234 }
    provider_request_id { "msg_#{SecureRandom.hex(8)}" }
    prompt_payload do
      {
        "model" => "claude-sonnet-4-6",
        "max_tokens" => 1024,
        "messages" => [ { "role" => "user", "content" => "Hello" } ]
      }
    end
    response_payload do
      {
        "id" => provider_request_id,
        "model" => "claude-sonnet-4-6",
        "content" => [ { "type" => "text", "text" => "Hi there!" } ],
        "usage" => { "input_tokens" => 100, "output_tokens" => 50 }
      }
    end

    trait :errored do
      input_tokens { 0 }
      output_tokens { 0 }
      total_cost_cents { 0 }
      provider_request_id { nil }
      response_payload do
        {
          "error" => {
            "class" => "Anthropic::Errors::InternalServerError",
            "message" => "Internal server error"
          }
        }
      end
    end
  end
end
