require "rails_helper"

RSpec.describe "Admin::PlayerCharacters", type: :request do
  let(:user)     { create(:user) }
  let(:campaign) { create(:campaign, user:) }

  before { host! "admin.gygaxagain.com" }

  describe "unauthenticated" do
    it "redirects to sign-in for index" do
      get admin_campaign_player_characters_path(campaign)
      expect(response).to have_http_status(:found)
      expect(response.location).to include("gygaxagain.com/users/sign_in")
    end
  end

  describe "authenticated" do
    before { sign_in user }

    describe "GET /admin/campaigns/:id/player_characters" do
      it "renders the index" do
        create(:player_character, campaign:, name: "Aragorn")
        get admin_campaign_player_characters_path(campaign)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Aragorn")
      end
    end

    describe "POST /admin/campaigns/:id/player_characters" do
      it "creates a PC" do
        expect {
          post admin_campaign_player_characters_path(campaign), params: {
            player_character: { name: "Aragorn", role: "pc", class_name: "Ranger", level: 1 }
          }
        }.to change { campaign.player_characters.count }.by(1)
        expect(response).to redirect_to(admin_campaign_player_characters_path(campaign))
      end

      it "re-renders the form on validation failure" do
        post admin_campaign_player_characters_path(campaign), params: {
          player_character: { name: "", role: "pc" }
        }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    describe "PATCH /admin/campaigns/:id/player_characters/:id" do
      it "updates" do
        pc = create(:player_character, campaign:, name: "Aragorn")
        patch admin_campaign_player_character_path(campaign, pc),
              params: { player_character: { name: "Strider" } }
        expect(pc.reload.name).to eq("Strider")
      end
    end

    describe "DELETE /admin/campaigns/:id/player_characters/:id" do
      it "destroys" do
        pc = create(:player_character, campaign:)
        expect {
          delete admin_campaign_player_character_path(campaign, pc)
        }.to change { campaign.player_characters.count }.by(-1)
      end
    end

    describe "scoping" do
      it "404s on another user's campaign" do
        other = create(:campaign)
        get admin_campaign_player_characters_path(other)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
