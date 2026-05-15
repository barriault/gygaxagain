require "rails_helper"

RSpec.describe Dice::Roll do
  describe ".call" do
    it "rolls a single die deterministically" do
      result = Dice::Random.with_fixed([ 4 ]) { described_class.call("1d6") }

      expect(result.expression).to eq("1d6")
      expect(result.total).to eq(4)
      expect(result.breakdown).to eq([ "1d6 = [4] = 4" ])
      expect(result.rolls).to eq([ [ 4 ] ])
    end

    it "rolls multiple dice and sums them" do
      result = Dice::Random.with_fixed([ 2, 5 ]) { described_class.call("2d6") }

      expect(result.total).to eq(7)
      expect(result.breakdown).to eq([ "2d6 = [2, 5] = 7" ])
      expect(result.rolls).to eq([ [ 2, 5 ] ])
    end

    it "adds a constant" do
      result = Dice::Random.with_fixed([ 4 ]) { described_class.call("1d6+3") }

      expect(result.total).to eq(7)
      expect(result.breakdown).to eq([ "1d6 = [4] = 4", "+3" ])
      expect(result.rolls).to eq([ [ 4 ], [] ])
    end

    it "subtracts a constant" do
      result = Dice::Random.with_fixed([ 18 ]) { described_class.call("1d20-1") }

      expect(result.total).to eq(17)
      expect(result.breakdown).to eq([ "1d20 = [18] = 18", "-1" ])
    end

    it "applies keep-highest" do
      result = Dice::Random.with_fixed([ 3, 5, 6, 2 ]) { described_class.call("4d6kh3") }

      expect(result.total).to eq(14) # 3 + 5 + 6 keep, 2 dropped
      expect(result.rolls).to eq([ [ 3, 5, 6, 2 ] ])
      expect(result.breakdown.first).to include("[3, 5, 6, 2]")
      expect(result.breakdown.first).to include("= 14")
    end

    it "applies keep-lowest" do
      result = Dice::Random.with_fixed([ 19, 2 ]) { described_class.call("2d20kl1") }

      expect(result.total).to eq(2)
    end

    it "keeps all dice when keep N >= count" do
      result = Dice::Random.with_fixed([ 1, 2, 3 ]) { described_class.call("3d6kh5") }

      expect(result.total).to eq(6)
    end

    it "applies drop-lowest with explicit count" do
      result = Dice::Random.with_fixed([ 3, 5, 6, 2 ]) { described_class.call("4d6dl1") }

      expect(result.total).to eq(14) # 3 + 5 + 6, drop 2
      expect(result.breakdown.first).to include("dl1")
    end

    it "applies drop-lowest without a count (defaults to 1)" do
      result = Dice::Random.with_fixed([ 19, 2 ]) { described_class.call("2d20dl") }

      expect(result.total).to eq(19) # keep 19, drop 2
      expect(result.breakdown.first).to include("dl1")
    end

    it "applies drop-highest without a count (defaults to 1)" do
      result = Dice::Random.with_fixed([ 19, 2 ]) { described_class.call("2d20dh") }

      expect(result.total).to eq(2) # keep 2, drop 19
      expect(result.breakdown.first).to include("dh1")
    end

    it "rolls a constant-only expression" do
      result = described_class.call("+5")
      expect(result.total).to eq(5)
      expect(result.breakdown).to eq([ "+5" ])
      expect(result.rolls).to eq([ [] ])
    end

    it "handles a leading negative constant" do
      result = described_class.call("-3")
      expect(result.total).to eq(-3)
      expect(result.breakdown).to eq([ "-3" ])
    end

    it "raises Dice::ParseError on malformed input" do
      expect { described_class.call("not dice") }.to raise_error(Dice::ParseError)
    end
  end
end
