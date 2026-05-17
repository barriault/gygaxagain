require "rails_helper"

RSpec.describe Narrator::ChipParser do
  describe ".parse" do
    it "extracts a single closed chip" do
      result = described_class.parse("Foo [[1d20+3 — Aragorn Strength]] bar.")
      expect(result.chips).to eq([
        { full: "[[1d20+3 — Aragorn Strength]]", expression: "1d20+3", pc_name: "Aragorn", reason: "Strength" }
      ])
      expect(result.open_chip?).to be(false)
    end

    it "detects an unclosed chip at end of text" do
      result = described_class.parse("He smirks. [[1d20+5 — Caine Insight")
      expect(result.open_chip?).to be(true)
      expect(result.open_chip[:expression]).to eq("1d20+5")
    end

    it "returns no chips for plain text" do
      result = described_class.parse("Just prose.")
      expect(result.chips).to be_empty
      expect(result.open_chip?).to be(false)
    end
  end
end
