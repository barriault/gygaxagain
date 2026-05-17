require "rails_helper"

RSpec.describe Play::Scenes::LogComponent, type: :component do
  let(:campaign) { create(:campaign) }
  let(:scene)    { create(:scene, campaign: campaign) }

  describe "with no events" do
    it "renders a text-only empty state" do
      render_inline(described_class.new(scene: scene))

      expect(page).to have_text(/the scene is set/i)
    end
  end

  describe "with events of multiple kinds" do
    let!(:narration_event) do
      create(:event,
             scene: scene,
             kind: "narration",
             payload: { "text" => "The tavern is quiet." },
             occurred_at: 5.minutes.ago)
    end
    let!(:dice_event) do
      create(:event, :dice_roll,
             scene: scene,
             payload: { "expression" => "2d6+3", "result" => 10 },
             occurred_at: 4.minutes.ago)
    end
    it "renders each event via its dedicated component" do
      render_inline(described_class.new(scene: scene))

      expect(page).to have_text("The tavern is quiet.")
      expect(page).to have_text("2d6+3")
    end

    it "renders events in chronological order (oldest to newest)" do
      rendered = render_inline(described_class.new(scene: scene)).to_s

      narration_pos = rendered.index("The tavern is quiet.")
      dice_pos      = rendered.index("2d6+3")

      expect(narration_pos).to be < dice_pos
    end
  end

  describe "turbo-frame structure" do
    it "wraps the events list in <turbo-frame id='scene_log_<id>'>" do
      render_inline(described_class.new(scene: scene))

      expect(page).to have_css("turbo-frame##{ApplicationController.helpers.dom_id(scene, :log)}")
    end

    it "gives the empty-state placeholder its own dom_id'd container" do
      render_inline(described_class.new(scene: scene))

      expect(page).to have_css("##{ApplicationController.helpers.dom_id(scene, :log_empty)}")
    end

    it "omits the empty-state container when events are present" do
      create(:event, scene: scene, kind: "narration", payload: { "text" => "An event." })

      render_inline(described_class.new(scene: scene))

      expect(page).not_to have_css("##{ApplicationController.helpers.dom_id(scene, :log_empty)}")
    end
  end

  describe "asymmetry" do
    let(:faction) { create(:faction, campaign: campaign) }
    let(:npc)     { create(:npc, campaign: campaign) }

    before do
      create(:event, scene: scene, kind: "narration", payload: { "text" => "Innocuous text." })
      create(:faction_secret, faction: faction, label: "hidden temple", content: "in the swamp")
      create(:npc_secret,     npc: npc,         label: "true identity", content: "is a doppelganger")
    end

    it "does not leak secrets of related records" do
      rendered = render_inline(described_class.new(scene: scene)).to_s
      expect(rendered).not_to leak_secrets_of(faction, npc)
    end
  end
end
