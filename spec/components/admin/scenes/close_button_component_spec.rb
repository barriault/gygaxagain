require "rails_helper"

RSpec.describe Admin::Scenes::CloseButtonComponent, type: :component do
  include Rails.application.routes.url_helpers

  let(:campaign) { create(:campaign) }
  let(:scene)    { create(:scene, campaign: campaign) }

  it "renders a clickable End scene button when scene is open" do
    rendered = render_inline(described_class.new(scene: scene))
    expect(rendered.css("button[type='submit']").text).to include("End scene")
  end

  it "renders a disabled Closed label when scene is closed" do
    scene.update!(closed_at: Time.current)
    rendered = render_inline(described_class.new(scene: scene))
    expect(rendered.css("button")).to be_empty
    expect(rendered.text).to include("Closed")
  end
end
