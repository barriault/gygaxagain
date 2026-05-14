require "rails_helper"

RSpec.describe "Phase 6 play surface (end-to-end)", type: :system do
  before { driven_by :rack_test }

  let(:password) { "correct horse battery staple" }
  let!(:user) { create(:user, password: password, password_confirmation: password) }
  let!(:campaign) { create(:campaign, user: user, name: "Curse of Strahd") }

  # Pre-condition: set last_played_campaign_id so that after_sign_in_path_for
  # redirects directly to the campaign play page (scene picker/placeholder)
  # rather than the generic campaign picker.  Without this, the redirect lands
  # on gygaxagain.com/campaigns (the picker) because last_played_campaign_id
  # is nil and the user has exactly one campaign.
  before do
    user.update!(last_played_campaign_id: campaign.id)
  end

  it "lets a user create a scene in admin and then play it" do
    # Sign in on apex.
    Capybara.app_host = "http://gygaxagain.com"
    visit "/users/sign_in"
    fill_in "Email", with: user.email
    fill_in "Password", with: password
    click_button "Log in"

    # With last_played_campaign_id set, the user lands on the play subdomain's
    # scene play page for the campaign — which shows the placeholder because no
    # scenes exist yet.
    expect(current_url).to include("gygaxagain.com/campaigns/#{campaign.id}/play")
    expect(page).to have_text(/no scenes yet/i)

    # Navigate to admin to create a scene.
    Capybara.app_host = "http://admin.gygaxagain.com"
    visit "/campaigns"
    click_link "Curse of Strahd"

    # Now on the campaign show page.
    expect(current_url).to include("admin.gygaxagain.com/campaigns/#{campaign.id}")
    expect(page).to have_text("Curse of Strahd")
    expect(page).to have_text(/no scenes yet/i)

    # Create a scene.
    click_link "New scene"
    fill_in "Title", with: "Tavern at Dusk"
    fill_in "Summary", with: "Rainy, quiet."
    click_button "Create scene"

    # Redirected back to the campaign show page; sees the new scene.
    expect(current_url).to include("admin.gygaxagain.com/campaigns/#{campaign.id}")
    expect(page).to have_text("Tavern at Dusk")
    expect(page).to have_text("Rainy, quiet.")

    # Switch to the play subdomain. The scene picker should now show the scene.
    Capybara.app_host = "http://gygaxagain.com"
    visit "/campaigns/#{campaign.id}/play"

    expect(page).to have_text("Choose a scene")
    expect(page).to have_link("Tavern at Dusk")

    # Click into the scene.
    click_link "Tavern at Dusk"

    # On the scene play page; sees the empty-log state.
    expect(current_url).to match(%r{gygaxagain\.com/campaigns/#{campaign.id}/scenes/\d+/play})
    expect(page).to have_text("Tavern at Dusk")
    expect(page).to have_text(/the scene is set/i)
  end
end
