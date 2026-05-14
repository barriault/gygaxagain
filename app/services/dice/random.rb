require "securerandom"

module Dice
  module Random
    @fixed_queue = nil

    class << self
      attr_accessor :fixed_queue
    end

    module_function

    def roll(sides)
      queue = Dice::Random.fixed_queue
      if queue
        raise "Dice::Random fixed queue exhausted" if queue.empty?
        return queue.shift
      end
      SecureRandom.random_number(sides) + 1
    end

    def with_fixed(values)
      previous = Dice::Random.fixed_queue
      Dice::Random.fixed_queue = values.dup
      yield
    ensure
      Dice::Random.fixed_queue = previous
    end
  end
end
