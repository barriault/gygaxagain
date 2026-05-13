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
end
