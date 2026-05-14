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

  describe "with scenes" do
    let!(:scene_a) { create(:scene, campaign: campaign, title: "Scene Alpha") }
    let!(:scene_b) { create(:scene, campaign: campaign, title: "Scene Beta") }

    it "renders each scene as a row" do
      render_inline(described_class.new(campaign: campaign))

      expect(page).to have_text("Scene Alpha")
      expect(page).to have_text("Scene Beta")
    end

    it "does NOT render the empty-state copy" do
      render_inline(described_class.new(campaign: campaign))

      expect(page).not_to have_text(/no scenes yet/i)
    end
  end
end
