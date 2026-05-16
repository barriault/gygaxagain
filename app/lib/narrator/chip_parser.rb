module Narrator
  class ChipParser
    CHIP_RE      = /\[\[(?<expr>\S+)\s*(?:—|--|-)\s*(?<pc>[A-Za-z]+)\s+(?<reason>[^\]]+?)\]\]/
    OPEN_CHIP_RE = /\[\[(?<expr>\S*)\s*(?:—|--|-)?\s*(?<pc>[A-Za-z]*)?\s*(?<reason>[^\]]*?)\z/

    Result = Data.define(:chips, :open_chip) do
      def open_chip? = !open_chip.nil?
    end

    def self.parse(text)
      str = text.to_s
      chips = str.scan(CHIP_RE).map do |expr, pc, reason|
        { full: "[[#{expr} — #{pc} #{reason}]]", expression: expr, pc_name: pc, reason: reason.strip }
      end

      stripped = str.gsub(CHIP_RE, "")
      open = nil
      if (m = stripped.match(OPEN_CHIP_RE)) && m[:expr].to_s.length.positive?
        open = { expression: m[:expr], pc_name: m[:pc].to_s, reason: m[:reason].to_s.strip }
      end

      Result.new(chips: chips, open_chip: open)
    end
  end
end
