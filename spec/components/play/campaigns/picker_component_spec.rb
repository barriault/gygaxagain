require "rails_helper"

RSpec.describe Play::Campaigns::PickerComponent, type: :component do
  it "renders one link per campaign" do
    user = create(:user)
    campaigns = [create(:campaign, user: user, name: "Alpha"),
                 create(:campaign, user: user, name: "Beta")]

    render_inline(described_class.new(campaigns: campaigns))

    expect(page).to have_link("Alpha")
    expect(page).to have_link("Beta")
  end

  it "renders an empty-state when given an empty collection" do
    render_inline(described_class.new(campaigns: Campaign.none))
    expect(page).to have_text(/no campaigns/i)
  end
end
