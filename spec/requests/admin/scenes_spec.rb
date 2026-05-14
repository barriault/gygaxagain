require "rails_helper"

RSpec.describe "Admin::Scenes", type: :request do
  before { host! "admin.gygaxagain.com" }

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:campaign) { create(:campaign, user: user) }

  describe "GET /campaigns/:campaign_id/scenes/new" do
    context "authenticated" do
      before { sign_in user }

      it "renders the form" do
        get "/campaigns/#{campaign.id}/scenes/new"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("New scene")
      end
    end

    context "unauthenticated" do
      it "redirects to apex sign-in" do
        get "/campaigns/#{campaign.id}/scenes/new"
        expect(response).to have_http_status(:found)
        expect(response.location).to include("gygaxagain.com/users/sign_in")
      end
    end
  end

  describe "POST /campaigns/:campaign_id/scenes" do
    before { sign_in user }

    it "creates the scene and redirects to the campaign show page" do
      expect {
        post "/campaigns/#{campaign.id}/scenes",
             params: { scene: { title: "Tavern at Dusk", summary: "Rainy, quiet." } }
      }.to change { campaign.scenes.count }.by(1)

      expect(response).to redirect_to("/campaigns/#{campaign.id}")
      follow_redirect!
      expect(response.body).to include("Tavern at Dusk")
    end

    it "re-renders the form on validation failure" do
      post "/campaigns/#{campaign.id}/scenes",
           params: { scene: { title: "", summary: "Empty title" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("can&#39;t be blank").or include("can't be blank")
    end
  end

  describe "GET /campaigns/:campaign_id/scenes/:id/edit" do
    let!(:scene) { create(:scene, campaign: campaign, title: "Existing") }

    before { sign_in user }

    it "renders the edit form prefilled" do
      get "/campaigns/#{campaign.id}/scenes/#{scene.id}/edit"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Edit scene")
      expect(response.body).to include("Existing")
    end
  end

  describe "PATCH /campaigns/:campaign_id/scenes/:id" do
    let!(:scene) { create(:scene, campaign: campaign, title: "Old") }

    before { sign_in user }

    it "updates the scene and redirects to the campaign show page" do
      patch "/campaigns/#{campaign.id}/scenes/#{scene.id}",
            params: { scene: { title: "New", summary: "Updated" } }

      expect(response).to redirect_to("/campaigns/#{campaign.id}")
      expect(scene.reload.title).to eq("New")
      expect(scene.reload.summary).to eq("Updated")
    end
  end

  describe "DELETE /campaigns/:campaign_id/scenes/:id" do
    let!(:scene) { create(:scene, campaign: campaign) }

    before { sign_in user }

    it "deletes the scene and redirects to the campaign show page" do
      expect {
        delete "/campaigns/#{campaign.id}/scenes/#{scene.id}"
      }.to change { campaign.scenes.count }.by(-1)

      expect(response).to redirect_to("/campaigns/#{campaign.id}")
    end
  end

  describe "POST /campaigns/:campaign_id/scenes/:id/move_up + move_down" do
    let!(:first_scene)  { create(:scene, campaign: campaign, title: "First") }
    let!(:second_scene) { create(:scene, campaign: campaign, title: "Second") }

    before { sign_in user }

    it "move_up swaps positions and redirects" do
      post "/campaigns/#{campaign.id}/scenes/#{second_scene.id}/move_up"

      expect(response).to redirect_to("/campaigns/#{campaign.id}")
      expect(first_scene.reload.position).to eq(2)
      expect(second_scene.reload.position).to eq(1)
    end

    it "move_down swaps positions and redirects" do
      post "/campaigns/#{campaign.id}/scenes/#{first_scene.id}/move_down"

      expect(response).to redirect_to("/campaigns/#{campaign.id}")
      expect(first_scene.reload.position).to eq(2)
      expect(second_scene.reload.position).to eq(1)
    end

    it "move_up at the top is a no-op (idempotent)" do
      original_position = first_scene.position
      post "/campaigns/#{campaign.id}/scenes/#{first_scene.id}/move_up"

      expect(response).to redirect_to("/campaigns/#{campaign.id}")
      expect(first_scene.reload.position).to eq(original_position)
    end
  end

  describe "GET /campaigns/:campaign_id/scenes (index)" do
    before { sign_in user }

    it "redirects to the campaign show page" do
      get "/campaigns/#{campaign.id}/scenes"

      expect(response).to redirect_to("/campaigns/#{campaign.id}")
    end
  end

  describe "tenant scoping" do
    let(:other_campaign) { create(:campaign, user: other_user) }
    let!(:scene) { create(:scene, campaign: other_campaign) }

    before { sign_in user }

    it "404s on accessing a scene of another user's campaign" do
      get "/campaigns/#{other_campaign.id}/scenes/#{scene.id}/edit"
      expect(response).to have_http_status(:not_found)
    end
  end
end
