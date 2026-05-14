require "rails_helper"

RSpec.describe Mythic::Oracle do
  describe ".call" do
    it "returns a structured result with all fields populated" do
      result = Mythic::Random.with_fixed_d100([ 50 ]) do
        described_class.call(question: "Does it rain?", likelihood: "50_50", chaos_factor: 5)
      end

      expect(result.question).to eq("Does it rain?")
      expect(result.likelihood).to eq("50_50")
      expect(result.chaos_factor).to eq(5)
      expect(result.roll).to eq(50)
      expect(result.outcome).to eq(:yes)
      expect(result.random_event_triggered).to eq(false)
    end

    it "selects each outcome band correctly for 50_50 / CF 5 (bands 10 50 90 100)" do
      cases = {
        1   => :exceptional_yes,
        10  => :exceptional_yes,
        11  => :yes,
        50  => :yes,
        51  => :no,
        90  => :no,
        91  => :exceptional_no,
        100 => :exceptional_no
      }

      cases.each do |roll, expected_outcome|
        result = Mythic::Random.with_fixed_d100([ roll ]) do
          described_class.call(question: "q", likelihood: "50_50", chaos_factor: 5)
        end
        expect(result.outcome).to eq(expected_outcome),
          "expected roll #{roll} to produce #{expected_outcome}, got #{result.outcome}"
      end
    end

    describe "random event trigger rule (Mythic 2e p.35)" do
      [ 11, 22, 33, 44, 55, 66, 77, 88, 99 ].each do |roll|
        leading_digit = roll / 10

        it "triggers when roll=#{roll} and chaos_factor=#{leading_digit}" do
          result = Mythic::Random.with_fixed_d100([ roll ]) do
            described_class.call(question: "q", likelihood: "50_50", chaos_factor: leading_digit)
          end
          expect(result.random_event_triggered).to eq(true)
        end

        if leading_digit > 1
          it "does NOT trigger when roll=#{roll} and chaos_factor=#{leading_digit - 1}" do
            result = Mythic::Random.with_fixed_d100([ roll ]) do
              described_class.call(question: "q", likelihood: "50_50", chaos_factor: leading_digit - 1)
            end
            expect(result.random_event_triggered).to eq(false)
          end
        end
      end

      [ 1, 5, 10, 12, 21, 47, 89, 100 ].each do |roll|
        it "never triggers for non-doubled roll=#{roll} regardless of chaos" do
          (1..9).each do |cf|
            result = Mythic::Random.with_fixed_d100([ roll ]) do
              described_class.call(question: "q", likelihood: "50_50", chaos_factor: cf)
            end
            expect(result.random_event_triggered).to eq(false),
              "expected roll=#{roll} chaos=#{cf} not to trigger"
          end
        end
      end
    end

    it "raises ArgumentError for an invalid likelihood" do
      expect {
        described_class.call(question: "q", likelihood: "definitely", chaos_factor: 5)
      }.to raise_error(ArgumentError)
    end

    it "raises ArgumentError for an out-of-range chaos factor" do
      expect {
        described_class.call(question: "q", likelihood: "50_50", chaos_factor: 0)
      }.to raise_error(ArgumentError)
    end
  end
end
