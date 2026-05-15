require "rails_helper"

RSpec.describe "Admin::SceneClosures", type: :request do
  before { host! "admin.gygaxagain.com" }

  let(:user)     { create(:user) }
  let(:campaign) { create(:campaign, user: user) }
  let(:scene)    { create(:scene, campaign: campaign) }

  describe "POST /campaigns/:campaign_id/scenes/:scene_id/closure" do
    let(:path) { "/campaigns/#{campaign.id}/scenes/#{scene.id}/closure" }

    context "authenticated" do
      before { sign_in user }

      it "sets closed_at and enqueues SceneAuditJob" do
        expect {
          post path
        }.to change { scene.reload.closed_at }.from(nil)
         .and have_enqueued_job(SceneAuditJob).with(scene.id)

        expect(response).to redirect_to("/campaigns/#{campaign.id}")
        follow_redirect!
        expect(flash[:notice]).to include("Scene closed")
      end

      it "rejects already-closed scenes with an alert" do
        scene.update!(closed_at: Time.current)
        expect {
          post path
        }.not_to have_enqueued_job(SceneAuditJob)

        expect(response).to redirect_to("/campaigns/#{campaign.id}")
        follow_redirect!
        expect(flash[:alert]).to include("already closed")
      end

      it "404s on cross-user access" do
        other_campaign = create(:campaign, user: create(:user))
        other_scene = create(:scene, campaign: other_campaign)
        post "/campaigns/#{other_campaign.id}/scenes/#{other_scene.id}/closure"
        expect(response).to have_http_status(:not_found)
      end
    end

    context "unauthenticated" do
      it "redirects to apex sign-in" do
        post path
        expect(response).to have_http_status(:found)
        expect(response.location).to include("gygaxagain.com/users/sign_in")
      end
    end
  end
end
