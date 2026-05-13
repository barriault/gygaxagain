require "rails_helper"

RSpec.describe "After sign-in redirect", type: :request do
  let(:password) { "correct horse battery staple" }
  let(:user) { create(:user, password: password, password_confirmation: password) }

  def sign_in_with(user)
    post "/users/sign_in",
         params: { user: { email: user.email, password: password } }
  end

  context "when the user has a last_played_campaign (still owned)" do
    it "redirects to play_campaign_url on apex" do
      campaign = create(:campaign, user: user)
      user.update_column(:last_played_campaign_id, campaign.id)

      sign_in_with(user)

      expect(response).to have_http_status(:redirect)
      expect(response.location).to include("gygaxagain.com/campaigns/#{campaign.id}/play")
    end
  end

  context "when the user has campaigns but no last_played" do
    it "redirects to the play picker (campaigns_url on apex)" do
      create(:campaign, user: user)

      sign_in_with(user)

      expect(response).to have_http_status(:redirect)
      expect(response.location).to match(%r{gygaxagain\.com/campaigns(?!/)})
    end
  end

  context "when the user has zero campaigns" do
    it "redirects to new_admin_campaign_url" do
      sign_in_with(user)

      expect(response).to have_http_status(:redirect)
      expect(response.location).to include("admin.gygaxagain.com/campaigns/new")
    end
  end

  context "when last_played_campaign_id is stale (campaign deleted)" do
    it "falls through to the next case" do
      campaign = create(:campaign, user: user)
      user.update_column(:last_played_campaign_id, campaign.id)
      campaign.destroy  # FK nullify should clear the column

      sign_in_with(user)

      # User now has zero campaigns, so falls through to new_admin_campaign_url.
      expect(response).to have_http_status(:redirect)
      expect(response.location).to include("admin.gygaxagain.com/campaigns/new")
    end
  end
end
