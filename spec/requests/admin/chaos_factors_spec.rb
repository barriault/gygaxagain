require "rails_helper"

RSpec.describe "Admin::ChaosFactors", type: :request do
  before { host! "admin.gygaxagain.com" }

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:campaign) { create(:campaign, user: user, chaos_factor: 5) }

  describe "PATCH /campaigns/:campaign_id/chaos_factor" do
    context "authenticated" do
      before { sign_in user }

      it "increments when direction=up" do
        patch "/campaigns/#{campaign.id}/chaos_factor", params: { direction: "up" }

        expect(response).to redirect_to("/campaigns/#{campaign.id}")
        expect(campaign.reload.chaos_factor).to eq(6)
      end

      it "decrements when direction=down" do
        patch "/campaigns/#{campaign.id}/chaos_factor", params: { direction: "down" }

        expect(response).to redirect_to("/campaigns/#{campaign.id}")
        expect(campaign.reload.chaos_factor).to eq(4)
      end

      it "clamps at the ceiling" do
        campaign.update!(chaos_factor: 9)
        patch "/campaigns/#{campaign.id}/chaos_factor", params: { direction: "up" }

        expect(campaign.reload.chaos_factor).to eq(9)
      end

      it "clamps at the floor" do
        campaign.update!(chaos_factor: 1)
        patch "/campaigns/#{campaign.id}/chaos_factor", params: { direction: "down" }

        expect(campaign.reload.chaos_factor).to eq(1)
      end

      it "is a no-op when direction is missing or invalid" do
        patch "/campaigns/#{campaign.id}/chaos_factor", params: { direction: "" }
        expect(campaign.reload.chaos_factor).to eq(5)

        patch "/campaigns/#{campaign.id}/chaos_factor", params: { direction: "sideways" }
        expect(campaign.reload.chaos_factor).to eq(5)
      end

      it "returns 404 for a campaign owned by another user" do
        other_campaign = create(:campaign, user: other_user, chaos_factor: 5)
        patch "/campaigns/#{other_campaign.id}/chaos_factor", params: { direction: "up" }
        expect(response).to have_http_status(:not_found)
        expect(other_campaign.reload.chaos_factor).to eq(5)
      end
    end

    context "unauthenticated" do
      it "redirects to apex sign-in" do
        patch "/campaigns/#{campaign.id}/chaos_factor", params: { direction: "up" }
        expect(response).to have_http_status(:found)
        expect(response.location).to include("gygaxagain.com/users/sign_in")
      end
    end
  end
end
