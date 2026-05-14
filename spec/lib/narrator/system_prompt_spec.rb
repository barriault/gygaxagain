require "rails_helper"

RSpec.describe Narrator::SystemPrompt do
  it "has a non-empty text constant" do
    expect(described_class.text).to be_a(String)
    expect(described_class.text.length).to be > 200
  end

  it "documents the asymmetry contract" do
    expect(described_class.text).to match(/asymmetry|hidden|do not invent|prompt/i)
  end

  it "is frozen so callers cannot mutate it accidentally" do
    expect(described_class.text).to be_frozen
  end
end
