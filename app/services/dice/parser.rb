module Dice
  module Parser
    DiceTerm     = Data.define(:count, :sides, :sign, :keep)
    ConstantTerm = Data.define(:value, :sign)

    MAX_COUNT = 100
    MAX_SIDES = 10_000

    TERM_RE = /
      \A
      \s*
      (?<sign>[+-])?\s*
      (?:
        (?<count>\d+)d(?<sides>\d+)
        (?:k(?<keep>[hl])(?<keep_n>\d+))?
        |
        (?<const>\d+)
      )
    /x

    module_function

    def parse(expression)
      raise Dice::ParseError, "empty dice expression" if expression.nil? || expression.strip.empty?

      s = expression.strip
      pos = 0
      terms = []
      first = true

      while pos < s.length
        remaining = s[pos..]
        match = TERM_RE.match(remaining)
        raise Dice::ParseError, "unparseable at position #{pos}: #{remaining.inspect}" if match.nil?

        sign_str = match[:sign]
        sign =
          if first && sign_str.nil?
            1
          elsif sign_str.nil?
            raise Dice::ParseError, "missing operator at position #{pos}: #{remaining.inspect}"
          else
            sign_str == "+" ? 1 : -1
          end

        if match[:const]
          terms << ConstantTerm.new(value: match[:const].to_i, sign: sign)
        else
          count = match[:count].to_i
          sides = match[:sides].to_i
          raise Dice::ParseError, "count must be between 1 and #{MAX_COUNT}, got #{count}" if count < 1 || count > MAX_COUNT
          raise Dice::ParseError, "sides must be between 1 and #{MAX_SIDES}, got #{sides}" if sides < 1 || sides > MAX_SIDES

          keep = nil
          if match[:keep]
            keep_n = match[:keep_n].to_i
            raise Dice::ParseError, "keep count must be >= 1, got #{keep_n}" if keep_n < 1
            keep = [ match[:keep].to_sym, keep_n ]
          end

          terms << DiceTerm.new(count: count, sides: sides, sign: sign, keep: keep)
        end

        pos += match.end(0)
        first = false
        pos += 1 while pos < s.length && s[pos] == " "
      end

      raise Dice::ParseError, "no terms parsed from #{expression.inspect}" if terms.empty?

      terms
    end
  end
end
