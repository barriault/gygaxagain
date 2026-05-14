require "rails_helper"

RSpec.describe Admin::Campaigns::IndexComponent, type: :component do
  it "renders one row per campaign" do
    user = create(:user)
    campaigns = [ create(:campaign, user: user, name: "Alpha"),
                 create(:campaign, user: user, name: "Beta") ]
    render_inline(described_class.new(campaigns: campaigns))
    expect(page).to have_text("Alpha")
    expect(page).to have_text("Beta")
  end

  it "renders an empty-state when given an empty collection" do
    render_inline(described_class.new(campaigns: Campaign.none))
    expect(page).to have_text(/no campaigns/i)
  end

  it "renders a 'New campaign' CTA" do
    render_inline(described_class.new(campaigns: Campaign.none))
    expect(page).to have_link("New campaign")
  end
end
