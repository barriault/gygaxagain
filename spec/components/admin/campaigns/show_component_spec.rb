require "rails_helper"

RSpec.describe Admin::Campaigns::ShowComponent, type: :component do
  include Rails.application.routes.url_helpers

  let(:campaign) { create(:campaign, name: "Curse of Strahd", description: "Gothic horror.") }

  it "renders the campaign name and description" do
    render_inline(described_class.new(campaign: campaign))

    expect(page).to have_text("Curse of Strahd")
    expect(page).to have_text("Gothic horror.")
  end

  it "renders a Scenes section header" do
    render_inline(described_class.new(campaign: campaign))

    expect(page).to have_text(/scenes/i)
  end

  it "renders a 'New scene' link" do
    render_inline(described_class.new(campaign: campaign))

    expect(page).to have_link("New scene", href: new_admin_campaign_scene_path(campaign))
  end

  it "renders an empty state when the campaign has no scenes" do
    render_inline(described_class.new(campaign: campaign))

    expect(page).to have_text(/no scenes yet/i)
  end

  it "renders a Back-to-campaigns link" do
    render_inline(described_class.new(campaign: campaign))

    expect(page).to have_link("Back to campaigns", href: admin_campaigns_path)
  end
end
