require "rails_helper"

RSpec.describe Mythic::Random do
  describe ".d100" do
    it "returns a value between 1 and 100" do
      100.times do
        result = described_class.d100
        expect(result).to be_between(1, 100)
      end
    end

    it "covers a wide range across many rolls" do
      seen = Set.new
      1000.times { seen << described_class.d100 }
      expect(seen.size).to be > 50
    end
  end

  describe ".with_fixed_d100" do
    it "returns the queued values in order" do
      described_class.with_fixed_d100([ 11, 50, 99 ]) do
        expect(described_class.d100).to eq(11)
        expect(described_class.d100).to eq(50)
        expect(described_class.d100).to eq(99)
      end
    end

    it "resets to real randomness after the block" do
      described_class.with_fixed_d100([ 42 ]) { described_class.d100 }
      expect(described_class.d100).to be_between(1, 100)
    end

    it "raises if the queue underflows inside the block" do
      expect {
        described_class.with_fixed_d100([ 1 ]) do
          described_class.d100
          described_class.d100
        end
      }.to raise_error(/fixed.*exhausted/i)
    end
  end
end
