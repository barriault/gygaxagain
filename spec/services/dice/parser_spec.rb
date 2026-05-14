require "rails_helper"

RSpec.describe Dice::Parser do
  describe ".parse" do
    it "parses a single dice term" do
      result = described_class.parse("2d6")
      expect(result.length).to eq(1)
      term = result.first
      expect(term).to be_a(Dice::Parser::DiceTerm)
      expect(term.count).to eq(2)
      expect(term.sides).to eq(6)
      expect(term.sign).to eq(1)
      expect(term.keep).to be_nil
    end

    it "parses a dice term plus a constant" do
      result = described_class.parse("2d6+3")
      expect(result.length).to eq(2)
      expect(result[0]).to be_a(Dice::Parser::DiceTerm)
      expect(result[1]).to be_a(Dice::Parser::ConstantTerm)
      expect(result[1].value).to eq(3)
      expect(result[1].sign).to eq(1)
    end

    it "parses subtraction" do
      result = described_class.parse("1d20-1")
      expect(result.length).to eq(2)
      expect(result[1].sign).to eq(-1)
      expect(result[1].value).to eq(1)
    end

    it "parses keep-highest" do
      result = described_class.parse("4d6kh3")
      term = result.first
      expect(term.count).to eq(4)
      expect(term.sides).to eq(6)
      expect(term.keep).to eq([:h, 3])
    end

    it "parses keep-lowest" do
      result = described_class.parse("2d20kl1")
      term = result.first
      expect(term.keep).to eq([:l, 1])
    end

    it "parses keep-highest with a trailing constant" do
      result = described_class.parse("4d6kh3+2")
      expect(result.length).to eq(2)
      expect(result[0].keep).to eq([:h, 3])
      expect(result[1].value).to eq(2)
    end

    it "parses multiple dice terms" do
      result = described_class.parse("1d6+1d8")
      expect(result.length).to eq(2)
      expect(result[0]).to be_a(Dice::Parser::DiceTerm)
      expect(result[1]).to be_a(Dice::Parser::DiceTerm)
      expect(result[0].sides).to eq(6)
      expect(result[1].sides).to eq(8)
    end

    it "parses a leading negative" do
      result = described_class.parse("-1d6+5")
      expect(result[0].sign).to eq(-1)
      expect(result[1].sign).to eq(1)
    end

    it "parses a constant-only expression" do
      result = described_class.parse("+5")
      expect(result).to eq([Dice::Parser::ConstantTerm.new(value: 5, sign: 1)])
    end

    it "tolerates whitespace" do
      result = described_class.parse("  2d6 + 3 ")
      expect(result.length).to eq(2)
      expect(result[1].value).to eq(3)
    end

    describe "failure cases" do
      it "raises on empty input" do
        expect { described_class.parse("") }.to raise_error(Dice::ParseError, /empty/i)
      end

      it "raises on whitespace-only input" do
        expect { described_class.parse("   ") }.to raise_error(Dice::ParseError, /empty/i)
      end

      it "raises on missing operator between terms" do
        expect { described_class.parse("1d6 1d8") }.to raise_error(Dice::ParseError, /missing operator|unparseable/i)
      end

      it "raises on unparseable trailing input" do
        expect { described_class.parse("1d6+wat") }.to raise_error(Dice::ParseError)
      end

      it "raises on 0d6 (zero count)" do
        expect { described_class.parse("0d6") }.to raise_error(Dice::ParseError, /count/i)
      end

      it "raises on 1d0 (zero sides)" do
        expect { described_class.parse("1d0") }.to raise_error(Dice::ParseError, /sides/i)
      end

      it "raises on count above 100" do
        expect { described_class.parse("101d6") }.to raise_error(Dice::ParseError, /count/i)
      end

      it "raises on sides above 10_000" do
        expect { described_class.parse("1d10001") }.to raise_error(Dice::ParseError, /sides/i)
      end

      it "raises on kh0 (zero keep count)" do
        expect { described_class.parse("4d6kh0") }.to raise_error(Dice::ParseError, /keep/i)
      end
    end
  end
end
