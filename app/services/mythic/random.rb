require "securerandom"

module Mythic
  module Random
    @fixed_queue = nil

    class << self
      attr_accessor :fixed_queue
    end

    module_function

    def d100
      queue = Mythic::Random.fixed_queue
      if queue
        raise "Mythic::Random fixed queue exhausted" if queue.empty?
        return queue.shift
      end
      SecureRandom.random_number(100) + 1
    end

    def with_fixed_d100(values)
      previous = Mythic::Random.fixed_queue
      Mythic::Random.fixed_queue = values.dup
      yield
    ensure
      Mythic::Random.fixed_queue = previous
    end
  end
end
