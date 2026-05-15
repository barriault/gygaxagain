require "rails_helper"

RSpec.describe Admin::Scenes::RowComponent, type: :component do
  include Rails.application.routes.url_helpers

  let(:campaign) { create(:campaign) }
  let!(:first_scene)  { create(:scene, campaign: campaign, title: "First",  summary: "First summary") }
  let!(:middle_scene) { create(:scene, campaign: campaign, title: "Middle", summary: "Middle summary") }
  let!(:last_scene)   { create(:scene, campaign: campaign, title: "Last",   summary: "Last summary") }

  it "renders the scene title and a truncated summary" do
    render_inline(described_class.new(scene: middle_scene))

    expect(page).to have_text("Middle")
    expect(page).to have_text("Middle summary")
  end

  it "renders Edit and Delete affordances" do
    render_inline(described_class.new(scene: middle_scene))

    expect(page).to have_link("Edit")
    expect(page).to have_button("Delete")
  end

  it "renders Up and Down buttons for a middle scene" do
    render_inline(described_class.new(scene: middle_scene))

    expect(page).to have_button("Up")
    expect(page).to have_button("Down")
  end

  it "disables Up for the first scene" do
    render_inline(described_class.new(scene: first_scene))

    expect(page).to have_button("Up", disabled: true)
    expect(page).to have_button("Down", disabled: false)
  end

  it "disables Down for the last scene" do
    render_inline(described_class.new(scene: last_scene))

    expect(page).to have_button("Up", disabled: false)
    expect(page).to have_button("Down", disabled: true)
  end

  it "renders the edit link to the edit path" do
    render_inline(described_class.new(scene: middle_scene))

    expect(page).to have_link("Edit", href: edit_admin_campaign_scene_path(campaign, middle_scene))
  end

  describe "scene closure UI" do
    let(:campaign) { create(:campaign) }

    it "renders the End scene button when scene is open" do
      scene = create(:scene, campaign: campaign)
      rendered = render_inline(described_class.new(scene: scene))
      expect(rendered.text).to include("End scene")
      expect(rendered.text).not_to include("View audit")
    end

    it "renders the View audit link when scene is closed" do
      scene = create(:scene, campaign: campaign, closed_at: Time.current)
      rendered = render_inline(described_class.new(scene: scene))
      expect(rendered.text).to include("Closed")
      expect(rendered.text).to include("View audit")
    end
  end
end
