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
require "rails_helper"

RSpec.describe LlmCall, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:campaign).optional }
  end

  describe "validations" do
    subject { build(:llm_call) }

    it { is_expected.to validate_presence_of(:purpose) }
    it { is_expected.to validate_presence_of(:provider) }
    it { is_expected.to validate_presence_of(:model) }
  end

  describe "#text" do
    it "extracts the response content text from response_payload" do
      call = build(:llm_call,
        response_payload: {
          "content" => [ { "type" => "text", "text" => "Hello, narrator." } ]
        }
      )
      expect(call.text).to eq("Hello, narrator.")
    end

    it "returns nil for an errored call" do
      call = build(:llm_call, :errored)
      expect(call.text).to be_nil
    end
  end

  describe "#successful?" do
    it "is true when response_payload has no error key" do
      expect(build(:llm_call)).to be_successful
    end

    it "is false when response_payload has an error key" do
      expect(build(:llm_call, :errored)).not_to be_successful
    end
  end

  describe "#error_message" do
    it "is nil for a successful call" do
      expect(build(:llm_call).error_message).to be_nil
    end

    it "extracts the error message for an errored call" do
      expect(build(:llm_call, :errored).error_message).to eq("Internal server error")
    end
  end

  describe "#total_cost_dollars" do
    it "divides total_cost_cents by 100" do
      expect(build(:llm_call, total_cost_cents: 250).total_cost_dollars).to eq(2.5)
    end
  end

  describe "cascade deletes" do
    it "is destroyed when its user is destroyed" do
      user = create(:user)
      create(:llm_call, user: user)
      expect { user.destroy }.to change(LlmCall, :count).by(-1)
    end

    it "is destroyed when its campaign is destroyed" do
      campaign = create(:campaign)
      create(:llm_call, user: campaign.user, campaign: campaign)
      expect { campaign.destroy }.to change(LlmCall, :count).by(-1)
    end
  end
end
