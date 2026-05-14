require "rails_helper"

RSpec.describe Admin::Scenes::FormComponent, type: :component do
  include Rails.application.routes.url_helpers

  let(:campaign) { create(:campaign) }

  describe "for a new scene" do
    let(:scene) { campaign.scenes.build }

    it "renders the new-scene title and a Create button" do
      render_inline(described_class.new(campaign: campaign, scene: scene))

      expect(page).to have_text(/new scene/i)
      expect(page).to have_button("Create scene")
    end

    it "posts to admin_campaign_scenes_path" do
      render_inline(described_class.new(campaign: campaign, scene: scene))

      expect(page).to have_css(
        "form[action='#{admin_campaign_scenes_path(campaign)}'][method='post']"
      )
    end
  end

  describe "for an existing scene" do
    let(:scene) { create(:scene, campaign: campaign, title: "Existing", summary: "Existing summary") }

    it "renders the edit-scene title and an Update button" do
      render_inline(described_class.new(campaign: campaign, scene: scene))

      expect(page).to have_text(/edit scene/i)
      expect(page).to have_button("Update scene")
      expect(page).to have_field("Title", with: "Existing")
      expect(page).to have_field("Summary", with: "Existing summary")
    end
  end

  describe "with validation errors" do
    let(:scene) do
      s = campaign.scenes.build(title: "")
      s.valid?
      s
    end

    it "renders inline error messages" do
      render_inline(described_class.new(campaign: campaign, scene: scene))

      expect(page).to have_text(/can't be blank/i)
    end
  end
end
