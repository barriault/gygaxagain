require "rails_helper"

RSpec.describe "Play::Campaigns", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe "GET /campaigns" do
    context "unauthenticated" do
      it "redirects to sign-in" do
        get "/campaigns"
        expect(response).to have_http_status(:found)
        expect(response.location).to include("/users/sign_in")
      end
    end

    context "authenticated" do
      before { sign_in user }

      it "renders the picker with the user's campaigns" do
        create(:campaign, user: user, name: "Mine")
        create(:campaign, user: other_user, name: "Theirs")

        get "/campaigns"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Mine")
        expect(response.body).not_to include("Theirs")
      end
    end
  end

  describe "GET /campaigns/:id/play" do
    context "unauthenticated" do
      it "redirects to sign-in" do
        campaign = create(:campaign, user: user)
        get "/campaigns/#{campaign.id}/play"
        expect(response).to have_http_status(:found)
        expect(response.location).to include("/users/sign_in")
      end
    end

    context "authenticated" do
      before { sign_in user }

      it "renders the scene picker when the campaign has scenes" do
        campaign = create(:campaign, user: user)
        create(:scene, campaign: campaign, title: "Tavern")

        get "/campaigns/#{campaign.id}/play"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Choose a scene")
        expect(response.body).to include("Tavern")
      end

      it "renders the empty-state placeholder when the campaign has no scenes" do
        campaign = create(:campaign, user: user)

        get "/campaigns/#{campaign.id}/play"

        expect(response).to have_http_status(:ok)
        expect(response.body).to match(/no scenes yet/i)
      end

      it "updates last_played_campaign_id regardless of scene count" do
        campaign = create(:campaign, user: user)

        get "/campaigns/#{campaign.id}/play"

        expect(user.reload.last_played_campaign_id).to eq(campaign.id)
      end

      it "404s for another user's campaign" do
        other = create(:campaign, user: other_user)

        get "/campaigns/#{other.id}/play"
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
