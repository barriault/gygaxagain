require "rails_helper"

RSpec.describe Mythic::FateChart do
  describe "LIKELIHOODS" do
    it "lists the 9 Mythic 2e likelihood values in worst-to-best order" do
      expect(described_class::LIKELIHOODS).to eq(%w[
        impossible nearly_impossible very_unlikely unlikely
        50_50
        likely very_likely nearly_certain certain
      ])
    end
  end

  describe "CHART" do
    it "covers all 81 cells" do
      expected_keys = described_class::LIKELIHOODS.product((1..9).to_a)
      expect(described_class::CHART.keys.sort).to eq(expected_keys.sort)
    end

    it "each cell is a 4-tuple with 0 <= a <= b <= c <= d == 100" do
      described_class::CHART.each do |(likelihood, cf), bands|
        a, b, c, d = bands
        expect(bands.length).to eq(4), "cell #{[ likelihood, cf ].inspect} has #{bands.length} values"
        expect(a).to be >= 0
        expect(a).to be <= b
        expect(b).to be <= c
        expect(c).to be <= d
        expect(d).to eq(100), "cell #{[ likelihood, cf ].inspect} has exc_no_max=#{d}, expected 100"
      end
    end

    it "matches the worked example on p.24 (50_50, CF 5 -> 10 50 91)" do
      expect(described_class::CHART[[ "50_50", 5 ]]).to eq([ 10, 50, 90, 100 ])
    end
  end

  describe ".bands_for" do
    it "returns the cell for valid (likelihood, chaos_factor)" do
      expect(described_class.bands_for(likelihood: "likely", chaos_factor: 5))
        .to eq([ 13, 65, 93, 100 ])
    end

    it "raises ArgumentError for an unknown likelihood" do
      expect {
        described_class.bands_for(likelihood: "extremely", chaos_factor: 5)
      }.to raise_error(ArgumentError, /no chart cell/)
    end

    it "raises ArgumentError for a chaos factor outside 1..9" do
      expect {
        described_class.bands_for(likelihood: "likely", chaos_factor: 0)
      }.to raise_error(ArgumentError, /no chart cell/)
    end
  end

  describe ".outcome_for" do
    let(:bands) { [ 10, 50, 90, 100 ] } # 50_50 / CF 5

    it "returns :exceptional_yes for roll <= exc_yes_max" do
      expect(described_class.outcome_for(roll: 1, bands: bands)).to eq(:exceptional_yes)
      expect(described_class.outcome_for(roll: 10, bands: bands)).to eq(:exceptional_yes)
    end

    it "returns :yes for exc_yes_max < roll <= yes_max" do
      expect(described_class.outcome_for(roll: 11, bands: bands)).to eq(:yes)
      expect(described_class.outcome_for(roll: 50, bands: bands)).to eq(:yes)
    end

    it "returns :no for yes_max < roll <= no_max" do
      expect(described_class.outcome_for(roll: 51, bands: bands)).to eq(:no)
      expect(described_class.outcome_for(roll: 90, bands: bands)).to eq(:no)
    end

    it "returns :exceptional_no for no_max < roll <= exc_no_max" do
      expect(described_class.outcome_for(roll: 91, bands: bands)).to eq(:exceptional_no)
      expect(described_class.outcome_for(roll: 100, bands: bands)).to eq(:exceptional_no)
    end
  end
end
