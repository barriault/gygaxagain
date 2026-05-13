require "rails_helper"

RSpec.describe "Cross-subdomain session", type: :request do
  let(:user) { create(:user) }

  it "carries a session from apex to admin without re-auth" do
    # Sign in at apex using Devise helper.
    host! "gygaxagain.com"
    sign_in user

    # Navigate to admin. The session should be available across domains
    # because Rack::Test's cookie jar respects the domain attribute
    # (which our session_store sets to .gygaxagain.com via domain: :all + tld_length: 2).
    host! "admin.gygaxagain.com"
    get "/dashboard"

    expect(response).to have_http_status(:ok)
    expect(response.body).to match(/admin dashboard/i)
  end
end
