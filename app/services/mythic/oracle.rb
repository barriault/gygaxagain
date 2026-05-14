module Mythic
  class Oracle
    Result = Data.define(
      :question, :likelihood, :chaos_factor,
      :roll, :outcome, :random_event_triggered
    )

    def self.call(question:, likelihood:, chaos_factor:)
      bands = Mythic::FateChart.bands_for(likelihood: likelihood, chaos_factor: chaos_factor)
      roll = Mythic::Random.d100
      outcome = Mythic::FateChart.outcome_for(roll: roll, bands: bands)
      triggered = random_event?(roll: roll, chaos_factor: chaos_factor)

      Result.new(
        question: question,
        likelihood: likelihood,
        chaos_factor: chaos_factor,
        roll: roll,
        outcome: outcome,
        random_event_triggered: triggered
      )
    end

    def self.random_event?(roll:, chaos_factor:)
      return false unless roll.between?(11, 99)

      tens, units = roll.divmod(10)
      tens == units && tens <= chaos_factor
    end
  end
end
