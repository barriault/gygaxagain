require "rails_helper"

RSpec.describe "Phase 7: dice + oracle play mechanics", type: :system, js: true do
  let(:password) { "correct horse battery staple" }
  let(:user) { create(:user, password: password, password_confirmation: password) }
  let!(:campaign) { create(:campaign, user: user, name: "Curse", chaos_factor: 5) }
  let!(:scene)    { create(:scene, campaign: campaign, title: "Tavern at Dusk", summary: "Rainy.") }

  # lvh.me always resolves to 127.0.0.1 and supports arbitrary subdomains, so
  # Chrome can reach the local Capybara server without /etc/hosts edits.
  # Rails' default tld_length: 1 means "lvh.me" → subdomain "" and
  # "admin.lvh.me" → subdomain "admin" — matching the production topology.
  #
  # We sign in programmatically via Devise::Test::IntegrationHelpers so we can
  # navigate directly to the scene page without going through the login redirect
  # (which would otherwise point at the real gygaxagain.com production host).
  #
  # Because Turbo submits forms via fetch (asynchronously from Capybara's
  # perspective), the Dice::Random / Mythic::Random fixed queues must be set
  # BEFORE the click and left in place until the server consumes them. We set
  # them directly rather than using the with_fixed block wrapper, which would
  # restore the queue to nil before the async fetch reaches the server thread.
  before do
    Capybara.app_host = "http://lvh.me"
    sign_in user
  end

  after do
    Capybara.app_host = "http://gygaxagain.com"
    Dice::Random.fixed_queue   = nil
    Mythic::Random.fixed_queue = nil
  end

  it "rolls dice, asks the oracle, and adjusts chaos from admin" do
    # Navigate directly to the scene's play page on the apex (play) subdomain.
    visit play_campaign_scene_path(campaign, scene)
    expect(page).to have_text("Tavern at Dusk")
    expect(page).to have_text(/the scene is set/i)

    # Roll dice — fix the random queue before clicking so the server thread
    # sees [15] when it processes the async Turbo fetch request.
    Dice::Random.fixed_queue = [ 15 ]
    fill_in "dice_roll[expression]", with: "1d20"
    click_button "Roll"

    # Capybara waits until the Turbo Stream has been processed and the DOM
    # reflects the new event card.
    expect(page).to have_text("1d20")
    expect(page).to have_text("Result: 15")
    expect(page).not_to have_text(/the scene is set/i)

    # Ask the oracle — a roll of 33 with chaos 5 triggers a random event.
    Mythic::Random.fixed_queue = [ 33 ]
    fill_in "oracle_query[question]", with: "Does the door open?"
    select "Likely", from: "oracle_query[likelihood]"
    click_button "Ask"

    expect(page).to have_text("Does the door open?")
    expect(page).to have_text(/random event/i)

    # Switch to admin and bump chaos.
    Capybara.app_host = "http://admin.lvh.me"
    visit "/campaigns/#{campaign.id}"
    expect(page).to have_text(/chaos factor/i)
    find("button[data-direction='up']").click

    # Wait for the redirect+re-render to show the updated value before touching
    # the database, to avoid a race between the Capybara driver and the server.
    expect(page).to have_css("p", text: "6")
    expect(campaign.reload.chaos_factor).to eq(6)

    # Back to play; confirm the oracle form's chaos label updated.
    Capybara.app_host = "http://lvh.me"
    visit play_campaign_scene_path(campaign, scene)
    expect(page).to have_text("chaos 6")
  end

  describe "dice builder chips" do
    before do
      visit play_campaign_scene_path(campaign, scene)
    end

    it "builds 2d6+3 by tapping d6 twice and + three times, without submitting" do
      click_button "d6"
      click_button "d6"
      click_button "+"
      click_button "+"
      click_button "+"

      expect(page).to have_field("dice_roll[expression]", with: "2d6+3")
      # No event card appended — the dice scene log placeholder is still visible.
      expect(page).to have_text(/the scene is set/i)
    end

    it "disables other die chips once a die is selected" do
      click_button "d6"
      expect(page).to have_field("dice_roll[expression]", with: "1d6")

      d10 = page.find_button("d10")
      expect(d10["aria-disabled"]).to eq("true")

      click_button "d10"  # Capybara fires the click even on aria-disabled buttons.
      expect(page).to have_field("dice_roll[expression]", with: "1d6")
    end

    it "resets state and re-enables dice when clear is tapped" do
      click_button "d6"
      click_button "+"
      expect(page).to have_field("dice_roll[expression]", with: "1d6+1")

      click_button "clear"
      expect(page).to have_field("dice_roll[expression]", with: "")
      expect(page.find_button("d10")["aria-disabled"]).to eq("false")

      click_button "d10"
      expect(page).to have_field("dice_roll[expression]", with: "1d10")
    end

    it "increments and decrements the modifier across zero" do
      click_button "d6"
      click_button "+"
      click_button "+"
      expect(page).to have_field("dice_roll[expression]", with: "1d6+2")

      click_button "−"
      expect(page).to have_field("dice_roll[expression]", with: "1d6+1")

      click_button "−"
      click_button "−"
      expect(page).to have_field("dice_roll[expression]", with: "1d6-1")
    end
  end
end
