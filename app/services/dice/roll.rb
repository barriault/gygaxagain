module Dice
  class Roll
    Result = Data.define(:expression, :total, :breakdown, :rolls)

    def self.call(expression)
      new(expression).call
    end

    def initialize(expression)
      @expression = expression.to_s.strip
    end

    def call
      terms = Dice::Parser.parse(@expression)
      evaluated = terms.map { |term| evaluate(term) }

      total = evaluated.sum { |t| t[:value] }
      breakdown = evaluated.map { |t| t[:render] }
      rolls = evaluated.map { |t| t[:rolls] }

      Result.new(expression: @expression, total: total, breakdown: breakdown, rolls: rolls)
    end

    private

    def evaluate(term)
      case term
      when Dice::Parser::ConstantTerm
        value = term.sign * term.value
        { value: value, render: format_constant(term), rolls: [] }
      when Dice::Parser::DiceTerm
        rolls = Array.new(term.count) { Dice::Random.roll(term.sides) }
        kept, _dropped = apply_keep(rolls, term.keep)
        value = term.sign * kept.sum
        { value: value, render: format_dice(term, rolls, kept), rolls: rolls }
      end
    end

    def apply_keep(rolls, keep)
      return [ rolls.dup, [] ] if keep.nil?

      direction, n = keep
      return [ rolls.dup, [] ] if n >= rolls.length

      indexed = rolls.each_with_index.sort_by { |value, _| value }
      kept_indices =
        if direction == :h
          indexed.last(n).map(&:last).to_set
        else
          indexed.first(n).map(&:last).to_set
        end

      kept = rolls.each_with_index.select { |_, i| kept_indices.include?(i) }.map(&:first)
      dropped = rolls.each_with_index.reject { |_, i| kept_indices.include?(i) }.map(&:first)
      [ kept, dropped ]
    end

    def format_constant(term)
      sign = term.sign == 1 ? "+" : "-"
      "#{sign}#{term.value}"
    end

    def format_dice(term, rolls, kept)
      sign_prefix = term.sign == -1 ? "-" : ""
      keep_suffix = term.keep ? "k#{term.keep[0]}#{term.keep[1]}" : ""
      "#{sign_prefix}#{term.count}d#{term.sides}#{keep_suffix} = #{rolls.inspect} = #{kept.sum}"
    end
  end
end
