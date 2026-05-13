require "rails_helper"

RSpec.describe "Admin::Campaigns", type: :request do
  before { host! "admin.gygaxagain.com" }

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe "GET /campaigns" do
    context "unauthenticated" do
      it "redirects to apex sign-in" do
        get "/campaigns"
        expect(response).to have_http_status(:found)
        expect(response.location).to include("gygaxagain.com/users/sign_in")
      end
    end

    context "authenticated" do
      before { sign_in user }

      it "renders the index with the user's campaigns" do
        create(:campaign, user: user, name: "Mine")
        create(:campaign, user: other_user, name: "Theirs")

        get "/campaigns"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Mine")
        expect(response.body).not_to include("Theirs")
      end

      it "renders an empty-state when the user has no campaigns" do
        get "/campaigns"
        expect(response).to have_http_status(:ok)
        expect(response.body).to match(/no campaigns/i)
      end
    end
  end
end
