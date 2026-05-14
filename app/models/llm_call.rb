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
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class LlmCall < ApplicationRecord
  # Redact user-content payloads from #inspect and SQL bind logs.
  # Set explicitly (not `+=`) so the global :token filter doesn't false-match
  # our *_tokens count columns.
  self.filter_attributes = [ :prompt_payload, :response_payload ]

  belongs_to :user
  belongs_to :campaign, optional: true
  belongs_to :scene, optional: true

  validates :purpose,  presence: true
  validates :provider, presence: true
  validates :model,    presence: true

  def text
    return nil unless successful?
    response_payload.dig("content", 0, "text")
  end

  def successful?
    !response_payload.key?("error")
  end

  def error_message
    return nil if successful?
    response_payload.dig("error", "message")
  end

  def total_cost_dollars
    total_cost_cents / 100.0
  end
end
