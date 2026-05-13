require "rails_helper"

RSpec.describe Play::Campaigns::PlaceholderComponent, type: :component do
  it "renders the campaign name and a 'Phase 6' copy" do
    user = create(:user)
    campaign = create(:campaign, user: user, name: "Strahd")

    render_inline(described_class.new(campaign: campaign))

    expect(page).to have_text("Strahd")
    expect(page).to have_text(/phase 6|coming/i)
  end
end
