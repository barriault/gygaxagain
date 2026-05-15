require "rails_helper"

RSpec.describe Play::Events::PlayerActionComponent, type: :component do
  let(:scene) { create(:scene) }
  let(:event) {
    create(:event, scene: scene, kind: "player_action",
           payload: { "text" => "I open the door." })
  }

  it "renders the player text" do
    rendered = render_inline(described_class.new(event: event))
    expect(rendered.text).to include("I open the door.")
  end

  it "renders a relative timestamp" do
    travel_to Time.zone.parse("2026-05-14T20:00:00Z") do
      e = create(:event, scene: scene, kind: "player_action",
                 payload: { "text" => "x" }, occurred_at: 5.minutes.ago)
      rendered = render_inline(described_class.new(event: e))
      expect(rendered.text).to include("ago")
    end
  end

  it "carries the event's dom_id for stream targeting" do
    rendered = render_inline(described_class.new(event: event))
    expect(rendered.css("##{ActionView::RecordIdentifier.dom_id(event)}")).to be_present
  end

  describe "asymmetry" do
    let!(:faction) { create(:faction, :with_secrets, campaign: scene.campaign) }
    let!(:npc)     { create(:npc, :with_secrets, campaign: scene.campaign) }

    it "does not leak secrets" do
      rendered = render_inline(described_class.new(event: event)).to_s
      expect(rendered).not_to leak_secrets_of(faction, npc)
    end
  end
end
