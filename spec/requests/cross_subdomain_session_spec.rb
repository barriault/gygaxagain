require "rails_helper"

RSpec.describe "Cross-subdomain session", type: :request do
  let(:password) { "correct horse battery staple" }
  let(:user) { create(:user, password: password, password_confirmation: password) }

  it "carries a session from apex to admin without re-auth" do
    host! "gygaxagain.com"
    post "/users/sign_in",
         params: { user: { email: user.email, password: password } },
         headers: { "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" }

    # Devise is configured with responder.redirect_status = :see_other (303)
    # for Hotwire/Turbo compatibility. A 303 is a redirect — same intent as 302.
    expect(response).to have_http_status(:see_other)
    expect(response.location).to include("admin.gygaxagain.com")

    host! "admin.gygaxagain.com"
    get "/dashboard",
        headers: { "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to match(/admin dashboard/i)
  end
end
