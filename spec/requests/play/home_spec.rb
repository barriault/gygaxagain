require "rails_helper"

RSpec.describe "Play home", type: :request do
  describe "GET /" do
    context "unauthenticated" do
      it "redirects to sign-in" do
        get "/"
        expect(response).to have_http_status(:found)
        expect(response.location).to include("/users/sign_in")
      end
    end

    context "authenticated" do
      let(:user) { create(:user) }
      before { sign_in user }

      it "returns 200 OK" do
        get "/"
        expect(response).to have_http_status(:ok)
      end

      it "renders the project name" do
        get "/"
        expect(response.body).to include("gygaxagain")
      end

      it "renders the tagline" do
        get "/"
        expect(response.body).to include("solo D&amp;D")
      end

      it "marks the project as private alpha" do
        get "/"
        expect(response.body).to include("private alpha")
      end
    end
  end

  describe "controller auth chain" do
    it "applies authenticate_user! (no skip)" do
      before_filters = Play::HomeController._process_action_callbacks
                         .select { |cb| cb.kind == :before }
                         .map(&:filter)
      expect(before_filters).to include(:authenticate_user!)
    end
  end
end
