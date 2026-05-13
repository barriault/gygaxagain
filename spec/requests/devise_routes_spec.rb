require "rails_helper"

RSpec.describe "Devise routes", type: :request do
  describe "GET /users/sign_in" do
    it "renders the sign-in form" do
      get "/users/sign_in"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Log in").or include("Sign in")
    end
  end

  describe "GET /users/sign_up" do
    it "is not routable (sign-up disabled)" do
      get "/users/sign_up"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /users (registrations)" do
    it "is not routable (sign-up disabled)" do
      post "/users", params: { user: { email: "x@y.test", password: "x" * 12 } }
      expect(response).to have_http_status(:not_found)
    end
  end
end
