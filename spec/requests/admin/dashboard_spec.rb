require "rails_helper"

RSpec.describe "Admin dashboard", type: :request do
  before { host! "admin.gygaxagain.com" }

  describe "when not authenticated" do
    it "redirects to apex sign-in" do
      get "/dashboard"
      expect(response).to have_http_status(:found)
      expect(response.location).to include("gygaxagain.com/users/sign_in")
    end
  end

  describe "when authenticated" do
    let(:user) { create(:user) }
    before { sign_in user }

    it "renders the dashboard placeholder" do
      get "/dashboard"
      expect(response).to have_http_status(:ok)
      expect(response.body).to match(/admin dashboard/i)
    end
  end

  describe "controller auth chain" do
    it "inherits from ApplicationController (default-deny base)" do
      expect(Admin::DashboardController.ancestors).to include(ApplicationController)
    end

    it "fires authenticate_user! as a before_action" do
      filters = Admin::DashboardController._process_action_callbacks
                  .select { |cb| cb.kind == :before }
                  .map(&:filter)
      expect(filters).to include(:authenticate_user!)
    end
  end
end
