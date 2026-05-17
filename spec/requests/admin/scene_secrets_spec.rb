require "rails_helper"

RSpec.describe "Admin::SceneSecrets", type: :request do
  let(:user)     { create(:user) }
  let(:campaign) { create(:campaign, user:) }
  let(:scene)    { create(:scene, campaign:) }

  before { host! "admin.gygaxagain.com" }

  describe "authenticated" do
    before { sign_in user }

    it "GET index renders" do
      create(:scene_secret, scene:, label: "Encounter")
      get admin_campaign_scene_scene_secrets_path(campaign, scene)
      expect(response).to be_ok
      expect(response.body).to include("Encounter")
    end

    it "POST creates" do
      expect {
        post admin_campaign_scene_scene_secrets_path(campaign, scene), params: {
          scene_secret: { label: "Encounter", content: "2 skeletons" }
        }
      }.to change { scene.scene_secrets.count }.by(1)
    end

    it "PATCH updates" do
      secret = create(:scene_secret, scene:)
      patch admin_campaign_scene_scene_secret_path(campaign, scene, secret),
            params: { scene_secret: { content: "updated content" } }
      expect(secret.reload.content).to eq("updated content")
    end

    it "DELETE destroys" do
      secret = create(:scene_secret, scene:)
      expect {
        delete admin_campaign_scene_scene_secret_path(campaign, scene, secret)
      }.to change { scene.scene_secrets.count }.by(-1)
    end

    it "404s on another user's scene" do
      other = create(:scene)
      get admin_campaign_scene_scene_secrets_path(other.campaign, other)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "unauthenticated" do
    it "redirects to sign-in" do
      get admin_campaign_scene_scene_secrets_path(campaign, scene)
      expect(response).to have_http_status(:redirect)
      expect(response.location).to include("/users/sign_in")
    end
  end
end
