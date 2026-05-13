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

  describe "GET /campaigns/new" do
    context "unauthenticated" do
      it "redirects to apex sign-in" do
        get "/campaigns/new"
        expect(response).to have_http_status(:found)
        expect(response.location).to include("gygaxagain.com/users/sign_in")
      end
    end

    context "authenticated" do
      before { sign_in user }

      it "renders the form" do
        get "/campaigns/new"
        expect(response).to have_http_status(:ok)
        expect(response.body).to match(/New campaign/i)
        expect(response.body).to include('action="/campaigns"')
      end
    end
  end

  describe "POST /campaigns" do
    context "unauthenticated" do
      it "redirects to apex sign-in" do
        post "/campaigns", params: { campaign: { name: "X" } }
        expect(response).to have_http_status(:found)
        expect(response.location).to include("gygaxagain.com/users/sign_in")
      end
    end

    context "authenticated" do
      before { sign_in user }

      it "creates a campaign owned by the current user and redirects to the index" do
        expect {
          post "/campaigns", params: { campaign: { name: "Strahd", description: "Ravenloft" } }
        }.to change { user.campaigns.count }.by(1)

        expect(response).to have_http_status(:found)
        expect(response.location).to include("/campaigns")

        created = Campaign.find_by!(name: "Strahd")
        expect(created.user_id).to eq(user.id)
        expect(created.description).to eq("Ravenloft")
      end

      it "rerenders the form with 422 on invalid input" do
        post "/campaigns", params: { campaign: { name: "" } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to match(/can.?t be blank|prohibited this/i)
      end
    end
  end
end
