require "rails_helper"

RSpec.describe "Play::Scenes", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:campaign) { create(:campaign, user: user) }
  let(:scene) { create(:scene, campaign: campaign, title: "Tavern at Dusk") }

  describe "GET /campaigns/:campaign_id/scenes/:id/play" do
    context "unauthenticated" do
      it "redirects to sign-in" do
        get "/campaigns/#{campaign.id}/scenes/#{scene.id}/play"

        expect(response).to have_http_status(:found)
        expect(response.location).to include("/users/sign_in")
      end
    end

    context "authenticated" do
      before { sign_in user }

      it "renders the scene play page" do
        # Pre-create an event so we don't trigger framing on load
        create(:event, scene:, kind: "narration", payload: { "text" => "What do you do?" })

        get "/campaigns/#{campaign.id}/scenes/#{scene.id}/play"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Tavern at Dusk")
      end

      it "404s for a scene in another user's campaign" do
        other_campaign = create(:campaign, user: other_user)
        other_scene    = create(:scene, campaign: other_campaign)

        get "/campaigns/#{other_campaign.id}/scenes/#{other_scene.id}/play"
        expect(response).to have_http_status(:not_found)
      end

      it "404s when the scene exists but does not belong to the campaign in the URL" do
        # Two campaigns under the same user; scene belongs to campaign A, URL uses campaign B.
        campaign_b = create(:campaign, user: user)

        get "/campaigns/#{campaign_b.id}/scenes/#{scene.id}/play"
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "framing trigger" do
    include ActiveJob::TestHelper

    it "enqueues a framing NarrationJob when scene has zero events" do
      user     = create(:user)
      campaign = create(:campaign, user:)
      create(:player_character, campaign:, name: "Aragorn", role: "pc").tap { campaign.update!(main_character: _1) }
      scene = create(:scene, campaign:)
      sign_in user
      expect {
        get play_campaign_scene_path(campaign, scene)
      }.to have_enqueued_job(NarrationJob).with(hash_including(trigger: "framing"))
    end

    it "does not enqueue framing when events exist" do
      user     = create(:user)
      campaign = create(:campaign, user:)
      create(:player_character, campaign:, name: "Aragorn", role: "pc").tap { campaign.update!(main_character: _1) }
      scene = create(:scene, campaign:)
      create(:event, scene:, kind: "narration", payload: { "text" => "What do you do?" })
      sign_in user
      expect {
        get play_campaign_scene_path(campaign, scene)
      }.not_to have_enqueued_job(NarrationJob)
    end
  end
end
