require "rails_helper"

RSpec.describe Narrator::AuditSystemPrompt do
  it "has a non-empty text constant" do
    expect(described_class.text).to be_a(String)
    expect(described_class.text.length).to be > 200
  end

  it "names all four discipline criteria" do
    text = described_class.text
    %w[player_agency follow_through over_narration_of_intent mechanical_handoff].each do |name|
      expect(text).to include(name)
    end
  end

  it "specifies the JSON output schema" do
    expect(described_class.text).to include("verdict")
    expect(described_class.text).to include("criteria")
    expect(described_class.text).to include("summary")
  end

  it "is frozen" do
    expect(described_class.text).to be_frozen
  end
end
