require "rails_helper"

RSpec.describe Narrator::SystemPrompt do
  describe ".text" do
    it "contains the discipline preamble" do
      expect(described_class.text).to include("A roleplaying game is a conversation.")
    end

    it "contains the three-character-type contract" do
      expect(described_class.text).to include("Player characters (PCs)")
      expect(described_class.text).to include("Companions")
      expect(described_class.text).to include("Non-party characters (NPCs)")
    end

    it "tells the model never to generate the turn marker" do
      expect(described_class.text).to include("never generate")
      expect(described_class.text).to include("[Turn N]")
    end

    it "tells the model to use the dice-chip syntax" do
      expect(described_class.text).to include("[[")
      expect(described_class.text).to include("expression — PC name")
    end

    it "contains placeholder markers for pc_names and companion_names" do
      expect(described_class.text).to include("{pc_names}")
      expect(described_class.text).to include("{companion_names}")
    end
  end
end
