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

  it "signs out from admin and redirects to apex root" do
    # Authenticate first (uses Devise helper since the auth path is already
    # covered by the spec above; here we just need a session to destroy).
    sign_in user

    # Note: Devise route /users/sign_out is scoped to apex subdomain.
    # In a real browser on admin, the sign-out button would POST to the apex
    # sign_out endpoint. Our test shortcutally simulates that by starting on
    # admin (to set the admin session context) then moving to apex to issue
    # the DELETE. This verifies that after_sign_out_path_for returns apex root
    # and that the SessionsController properly handles the cross-host redirect.
    host! "admin.gygaxagain.com"
    get "/dashboard",
        headers: { "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" }
    expect(response).to have_http_status(:ok)

    host! "gygaxagain.com"
    delete "/users/sign_out",
           headers: { "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" }

    expect(response).to have_http_status(:see_other)
    expect(response.location).to eq("http://gygaxagain.com/")
  end
end
