require "rails_helper"

RSpec.describe "www subdomain", type: :request do
  it "301-redirects to apex preserving the path" do
    host! "www.gygaxagain.com"
    get "/users/sign_in"

    expect(response).to have_http_status(:moved_permanently)
    expect(response.location).to eq("http://gygaxagain.com/users/sign_in")
  end

  it "301-redirects the root path" do
    host! "www.gygaxagain.com"
    get "/"

    expect(response).to have_http_status(:moved_permanently)
    expect(response.location).to eq("http://gygaxagain.com/")
  end
end
