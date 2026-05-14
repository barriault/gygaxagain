require "rails_helper"

RSpec.describe Llm::DiagnosticsForm do
  describe "validations" do
    it "requires a prompt" do
      form = described_class.new(prompt: "", model: "claude-sonnet-4-6")
      expect(form).not_to be_valid
      expect(form.errors[:prompt]).to be_present
    end

    it "requires a model" do
      form = described_class.new(prompt: "Hi", model: nil)
      expect(form).not_to be_valid
      expect(form.errors[:model]).to be_present
    end

    it "rejects an unknown model" do
      form = described_class.new(prompt: "Hi", model: "claude-mythical-99")
      expect(form).not_to be_valid
      expect(form.errors[:model]).to be_present
    end

    it "accepts a known model" do
      form = described_class.new(prompt: "Hi", model: "claude-sonnet-4-6")
      expect(form).to be_valid
    end

    it "treats system_prompt as optional" do
      form = described_class.new(prompt: "Hi", model: "claude-sonnet-4-6", system_prompt: nil)
      expect(form).to be_valid
    end
  end
end
