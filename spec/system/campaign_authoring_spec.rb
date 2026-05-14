require "rails_helper"

RSpec.describe "Campaign authoring (end-to-end)", type: :system do
  before { driven_by :rack_test }

  let(:password) { "correct horse battery staple" }
  let!(:user) { create(:user, password: password, password_confirmation: password) }

  it "lets a user sign in, create, edit, and delete a campaign, then signs out" do
    # Sign in on apex.
    Capybara.app_host = "http://gygaxagain.com"
    visit "/users/sign_in"
    fill_in "Email", with: user.email
    fill_in "Password", with: password
    click_button "Log in"

    # Zero campaigns → landed on admin new-campaign form.
    expect(current_url).to include("admin.gygaxagain.com/campaigns/new")
    expect(page).to have_text(/new campaign/i)

    # Create a campaign.
    fill_in "Name", with: "Curse of Strahd"
    fill_in "Description", with: "Ravenloft, gothic horror."
    click_button "Create campaign"

    # Redirected to the admin index, sees the new campaign.
    expect(current_url).to include("admin.gygaxagain.com/campaigns")
    expect(page).to have_text("Curse of Strahd")

    # Edit it.
    click_link "Edit"
    expect(current_url).to match(%r{admin\.gygaxagain\.com/campaigns/\d+/edit})
    fill_in "Name", with: "Curse of Strahd: Revised"
    click_button "Update campaign"

    expect(current_url).to include("admin.gygaxagain.com/campaigns")
    expect(page).to have_text("Curse of Strahd: Revised")

    # Delete it. Turbo confirm isn't simulated under rack_test; the button_to
    # POSTs the delete directly.
    click_button "Delete"
    expect(current_url).to include("admin.gygaxagain.com/campaigns")
    expect(page).to have_text(/no campaigns yet/i)

    # Sign out from admin → lands on apex root.
    click_button "Sign out"
    expect(current_url).to eq("http://gygaxagain.com/")
  end
end
