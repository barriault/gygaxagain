require "rails_helper"

RSpec.describe Play::Narration::FormComponent, type: :component do
  let(:scene) { create(:scene) }

  it "renders a textarea, submit button, and helper text" do
    rendered = render_inline(described_class.new(scene: scene))
    expect(rendered.css("textarea[name='narration[text]']")).to be_present
    expect(rendered.css("button[type='submit']")).to be_present
    expect(rendered.text).to include("⌘+Enter to send").or include("Cmd+Enter to send")
  end

  it "carries the dom_id for stream targeting" do
    rendered = render_inline(described_class.new(scene: scene))
    expect(rendered.css("##{ActionView::RecordIdentifier.dom_id(scene, :narration_form)}")).to be_present
  end

  it "preserves sticky text on validation error" do
    rendered = render_inline(described_class.new(scene: scene, text: "I open the door.", error: "be more specific"))
    expect(rendered.css("textarea").text).to include("I open the door.")
    expect(rendered.text).to include("be more specific")
  end

  describe "asymmetry" do
    let!(:faction) { create(:faction, :with_secrets, campaign: scene.campaign) }
    let!(:npc)     { create(:npc, :with_secrets, campaign: scene.campaign) }

    it "does not leak secrets" do
      rendered = render_inline(described_class.new(scene: scene)).to_s
      expect(rendered).not_to leak_secrets_of(faction, npc)
    end
  end
end
