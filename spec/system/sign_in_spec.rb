require "rails_helper"

RSpec.describe "Sign in", type: :system do
  before do
    driven_by :rack_test
    Capybara.app_host = "http://gygaxagain.com"
  end

  let(:password) { "correct horse battery staple" }
  let!(:user) { create(:user, password: password, password_confirmation: password) }

  it "signs in via the apex form and lands on the admin dashboard" do
    visit "/users/sign_in"
    expect(page).to have_field("Email")
    expect(page).to have_field("Password")

    fill_in "Email", with: user.email
    fill_in "Password", with: password
    click_button "Log in"

    # After sign-in we should be on the admin dashboard.
    expect(current_url).to include("admin.gygaxagain.com")
    expect(page).to have_text(/admin dashboard/i)
  end
end
