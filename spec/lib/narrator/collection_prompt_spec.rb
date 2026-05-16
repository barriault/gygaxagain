require "rails_helper"

RSpec.describe Narrator::CollectionPrompt do
  describe ".companion_check" do
    it "returns a non-empty string mentioning all companion names" do
      result = described_class.companion_check([ "Caine", "Fred", "Patric" ])
      %w[Caine Fred Patric].each { expect(result).to include(_1) }
    end
  end

  describe ".next_pc" do
    it "for one name uses 'And X?' or 'What about X?'" do
      result = described_class.next_pc([ "Patric" ])
      expect(result).to satisfy { |s| s.include?("Patric") }
    end

    it "for multiple names lists them" do
      result = described_class.next_pc([ "Caine", "Patric" ])
      expect(result).to include("Caine").and include("Patric")
    end
  end

  describe ".short_circuit_decline" do
    it "lists remaining PCs and reminds about 'they hold'" do
      result = described_class.short_circuit_decline([ "Caine", "Patric" ])
      expect(result).to include("Caine").and include("Patric").and include("hold")
    end
  end

  describe ".no_focus_no_main" do
    it "asks for clarification" do
      expect(described_class.no_focus_no_main).to include("which PC")
    end
  end

  describe ".unknown_pc" do
    it "names the unknown" do
      expect(described_class.unknown_pc("Boromir")).to include("Boromir")
    end
  end

  describe ".format_names" do
    it "oxford-comma joins three" do
      expect(described_class.send(:format_names, %w[A B C])).to eq("A, B, and C")
    end

    it "joins two with 'and'" do
      expect(described_class.send(:format_names, %w[A B])).to eq("A and B")
    end

    it "passes one through" do
      expect(described_class.send(:format_names, %w[A])).to eq("A")
    end
  end
end
