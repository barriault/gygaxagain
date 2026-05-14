require "rails_helper"

RSpec.describe Dice::Random do
  describe ".roll" do
    it "returns a value between 1 and sides" do
      100.times do
        result = described_class.roll(6)
        expect(result).to be_between(1, 6)
      end
    end

    it "covers the full range over many rolls" do
      seen = Set.new
      1000.times { seen << described_class.roll(6) }
      expect(seen).to eq(Set.new([ 1, 2, 3, 4, 5, 6 ]))
    end
  end

  describe ".with_fixed" do
    it "returns the queued values in order" do
      described_class.with_fixed([ 3, 5, 1 ]) do
        expect(described_class.roll(6)).to eq(3)
        expect(described_class.roll(6)).to eq(5)
        expect(described_class.roll(6)).to eq(1)
      end
    end

    it "resets to real randomness after the block" do
      described_class.with_fixed([ 4 ]) { described_class.roll(6) }
      # Should not raise even though the queue is exhausted.
      expect(described_class.roll(6)).to be_between(1, 6)
    end

    it "raises if the queue underflows inside the block" do
      expect {
        described_class.with_fixed([ 1 ]) do
          described_class.roll(6)
          described_class.roll(6)
        end
      }.to raise_error(/fixed.*exhausted/i)
    end
  end
end
