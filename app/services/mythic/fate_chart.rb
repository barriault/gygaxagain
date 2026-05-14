module Mythic
  module FateChart
    LIKELIHOODS = %w[
      impossible nearly_impossible very_unlikely unlikely
      50_50
      likely very_likely nearly_certain certain
    ].freeze

    CHART = {
      [ "certain", 1 ] => [ 10, 50, 90, 100 ],
      [ "certain", 2 ] => [ 13, 65, 93, 100 ],
      [ "certain", 3 ] => [ 15, 75, 95, 100 ],
      [ "certain", 4 ] => [ 17, 85, 97, 100 ],
      [ "certain", 5 ] => [ 18, 90, 98, 100 ],
      [ "certain", 6 ] => [ 19, 95, 99, 100 ],
      [ "certain", 7 ] => [ 20, 99, 100, 100 ],
      [ "certain", 8 ] => [ 20, 99, 100, 100 ],
      [ "certain", 9 ] => [ 20, 99, 100, 100 ],

      [ "nearly_certain", 1 ] => [ 7, 35, 87, 100 ],
      [ "nearly_certain", 2 ] => [ 10, 50, 90, 100 ],
      [ "nearly_certain", 3 ] => [ 13, 65, 93, 100 ],
      [ "nearly_certain", 4 ] => [ 15, 75, 95, 100 ],
      [ "nearly_certain", 5 ] => [ 17, 85, 97, 100 ],
      [ "nearly_certain", 6 ] => [ 18, 90, 98, 100 ],
      [ "nearly_certain", 7 ] => [ 19, 95, 99, 100 ],
      [ "nearly_certain", 8 ] => [ 20, 99, 100, 100 ],
      [ "nearly_certain", 9 ] => [ 20, 99, 100, 100 ],

      [ "very_likely", 1 ] => [ 5, 25, 85, 100 ],
      [ "very_likely", 2 ] => [ 7, 35, 87, 100 ],
      [ "very_likely", 3 ] => [ 10, 50, 90, 100 ],
      [ "very_likely", 4 ] => [ 13, 65, 93, 100 ],
      [ "very_likely", 5 ] => [ 15, 75, 95, 100 ],
      [ "very_likely", 6 ] => [ 17, 85, 97, 100 ],
      [ "very_likely", 7 ] => [ 18, 90, 98, 100 ],
      [ "very_likely", 8 ] => [ 19, 95, 99, 100 ],
      [ "very_likely", 9 ] => [ 20, 99, 100, 100 ],

      [ "likely", 1 ] => [ 3, 15, 83, 100 ],
      [ "likely", 2 ] => [ 5, 25, 85, 100 ],
      [ "likely", 3 ] => [ 7, 35, 87, 100 ],
      [ "likely", 4 ] => [ 10, 50, 90, 100 ],
      [ "likely", 5 ] => [ 13, 65, 93, 100 ],
      [ "likely", 6 ] => [ 15, 75, 95, 100 ],
      [ "likely", 7 ] => [ 17, 85, 97, 100 ],
      [ "likely", 8 ] => [ 18, 90, 98, 100 ],
      [ "likely", 9 ] => [ 19, 95, 99, 100 ],

      [ "50_50", 1 ] => [ 2, 10, 82, 100 ],
      [ "50_50", 2 ] => [ 3, 15, 83, 100 ],
      [ "50_50", 3 ] => [ 5, 25, 85, 100 ],
      [ "50_50", 4 ] => [ 7, 35, 87, 100 ],
      [ "50_50", 5 ] => [ 10, 50, 90, 100 ],
      [ "50_50", 6 ] => [ 13, 65, 93, 100 ],
      [ "50_50", 7 ] => [ 15, 75, 95, 100 ],
      [ "50_50", 8 ] => [ 17, 85, 97, 100 ],
      [ "50_50", 9 ] => [ 18, 90, 98, 100 ],

      [ "unlikely", 1 ] => [ 1, 5, 81, 100 ],
      [ "unlikely", 2 ] => [ 2, 10, 82, 100 ],
      [ "unlikely", 3 ] => [ 3, 15, 83, 100 ],
      [ "unlikely", 4 ] => [ 5, 25, 85, 100 ],
      [ "unlikely", 5 ] => [ 7, 35, 87, 100 ],
      [ "unlikely", 6 ] => [ 10, 50, 90, 100 ],
      [ "unlikely", 7 ] => [ 13, 65, 93, 100 ],
      [ "unlikely", 8 ] => [ 15, 75, 95, 100 ],
      [ "unlikely", 9 ] => [ 17, 85, 97, 100 ],

      [ "very_unlikely", 1 ] => [ 0, 1, 80, 100 ],
      [ "very_unlikely", 2 ] => [ 1, 5, 81, 100 ],
      [ "very_unlikely", 3 ] => [ 2, 10, 82, 100 ],
      [ "very_unlikely", 4 ] => [ 3, 15, 83, 100 ],
      [ "very_unlikely", 5 ] => [ 5, 25, 85, 100 ],
      [ "very_unlikely", 6 ] => [ 7, 35, 87, 100 ],
      [ "very_unlikely", 7 ] => [ 10, 50, 90, 100 ],
      [ "very_unlikely", 8 ] => [ 13, 65, 93, 100 ],
      [ "very_unlikely", 9 ] => [ 15, 75, 95, 100 ],

      [ "nearly_impossible", 1 ] => [ 0, 1, 80, 100 ],
      [ "nearly_impossible", 2 ] => [ 0, 1, 80, 100 ],
      [ "nearly_impossible", 3 ] => [ 1, 5, 81, 100 ],
      [ "nearly_impossible", 4 ] => [ 2, 10, 82, 100 ],
      [ "nearly_impossible", 5 ] => [ 3, 15, 83, 100 ],
      [ "nearly_impossible", 6 ] => [ 5, 25, 85, 100 ],
      [ "nearly_impossible", 7 ] => [ 7, 35, 87, 100 ],
      [ "nearly_impossible", 8 ] => [ 10, 50, 90, 100 ],
      [ "nearly_impossible", 9 ] => [ 13, 65, 93, 100 ],

      [ "impossible", 1 ] => [ 0, 1, 80, 100 ],
      [ "impossible", 2 ] => [ 0, 1, 80, 100 ],
      [ "impossible", 3 ] => [ 0, 1, 80, 100 ],
      [ "impossible", 4 ] => [ 1, 5, 81, 100 ],
      [ "impossible", 5 ] => [ 2, 10, 82, 100 ],
      [ "impossible", 6 ] => [ 3, 15, 83, 100 ],
      [ "impossible", 7 ] => [ 5, 25, 85, 100 ],
      [ "impossible", 8 ] => [ 7, 35, 87, 100 ],
      [ "impossible", 9 ] => [ 10, 50, 90, 100 ]
    }.freeze

    module_function

    def bands_for(likelihood:, chaos_factor:)
      CHART.fetch([ likelihood, chaos_factor ]) do
        raise ArgumentError,
              "no chart cell for likelihood=#{likelihood.inspect} chaos=#{chaos_factor.inspect}"
      end
    end

    def outcome_for(roll:, bands:)
      exc_yes_max, yes_max, no_max, _exc_no_max = bands
      return :exceptional_yes if roll <= exc_yes_max
      return :yes             if roll <= yes_max
      return :no              if roll <= no_max
      :exceptional_no
    end
  end
end
