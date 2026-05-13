require "rails_helper"

RSpec.describe "Play home", type: :request do
  describe "GET /" do
    before { get "/" }

    it "returns 200 OK" do
      expect(response).to have_http_status(:ok)
    end

    it "renders the project name" do
      expect(response.body).to include("gygaxagain")
    end

    it "renders the tagline" do
      expect(response.body).to include("solo D&amp;D")
    end

    it "marks the project as private alpha" do
      expect(response.body).to include("private alpha")
    end
  end
end
