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

    context "authenticated as owner" do
      before { sign_in user }

      it "renders the placeholder" do
        campaign = create(:campaign, user: user, name: "Strahd")
        get "/campaigns/#{campaign.id}/play"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Strahd")
        expect(response.body).to match(/phase 6|coming/i)
      end

      it "updates last_played_campaign_id" do
        campaign = create(:campaign, user: user)
        get "/campaigns/#{campaign.id}/play"
        user.reload
        expect(user.last_played_campaign_id).to eq(campaign.id)
      end
    end

    context "authenticated as another user" do
      before { sign_in other_user }

      it "404s on the foreign campaign and does not touch last_played" do
        foreign = create(:campaign, user: user)
        other_user.update_column(:last_played_campaign_id, nil)

        get "/campaigns/#{foreign.id}/play"
        expect(response).to have_http_status(:not_found)

        other_user.reload
        expect(other_user.last_played_campaign_id).to be_nil
      end
    end
  end
end
