require "rails_helper"

RSpec.describe "Admin::SceneAudits", type: :request do
  let(:user)     { create(:user) }
  let(:campaign) { create(:campaign, user: user) }
  let(:scene)    { create(:scene, campaign: campaign) }

  before do
    host! "admin.gygaxagain.com"
    sign_in user
  end

  describe "GET /campaigns/:cid/scenes/:sid/audit" do
    let(:path) { "/campaigns/#{campaign.id}/scenes/#{scene.id}/audit" }

    it "renders the running placeholder when no audit exists" do
      get path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Audit running")
    end

    it "renders the audit when present" do
      create(:scene_audit, scene: scene)
      get path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("PASS")
    end

    it "404s on cross-user access" do
      other = create(:scene, campaign: create(:campaign))
      get "/campaigns/#{other.campaign.id}/scenes/#{other.id}/audit"
      expect(response).to have_http_status(:not_found)
    end
  end
end
