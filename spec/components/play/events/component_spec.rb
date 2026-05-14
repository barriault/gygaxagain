require "rails_helper"

RSpec.describe Play::Events::Component do
  let(:campaign) { create(:campaign) }
  let(:scene)    { create(:scene, campaign: campaign) }

  describe ".for(event)" do
    it "returns NarrationComponent for kind=narration" do
      event = build(:event, scene: scene, kind: "narration")
      expect(described_class.for(event)).to eq(Play::Events::NarrationComponent)
    end

    it "returns DiceRollComponent for kind=dice_roll" do
      event = build(:event, scene: scene, kind: "dice_roll")
      expect(described_class.for(event)).to eq(Play::Events::DiceRollComponent)
    end

    it "returns OracleQueryComponent for kind=oracle_query" do
      event = build(:event, scene: scene, kind: "oracle_query")
      expect(described_class.for(event)).to eq(Play::Events::OracleQueryComponent)
    end

    it "returns SceneTransitionComponent for kind=scene_transition" do
      event = build(:event, scene: scene, kind: "scene_transition")
      expect(described_class.for(event)).to eq(Play::Events::SceneTransitionComponent)
    end

    it "raises ArgumentError for an unknown kind" do
      # We can't build an Event with an unknown kind through the enum, so
      # stub the kind reader directly to simulate the failure path.
      event = build(:event, scene: scene, kind: "narration")
      allow(event).to receive(:kind).and_return("not_a_real_kind")

      expect { described_class.for(event) }.to raise_error(ArgumentError, /no component registered/)
    end
  end

  describe "REGISTRY" do
    it "is frozen" do
      expect(described_class::REGISTRY).to be_frozen
    end

    it "covers all four event kinds" do
      expect(described_class::REGISTRY.keys).to contain_exactly(
        "narration", "dice_roll", "oracle_query", "scene_transition"
      )
    end

    it "REGISTRY keys are a subset of Event::KINDS" do
      # We assert subset (not equality) so a new Event kind can be introduced
      # in one commit and its component dispatcher entry added in a later one
      # without leaving an intermediate broken state. The reverse direction —
      # "every kind has a component" — is enforced at runtime by `.for(event)`
      # raising on unknown kinds.
      expect(described_class::REGISTRY.keys - Event::KINDS).to be_empty
    end
  end
end
