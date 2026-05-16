module Narrator
  class DeclarationParser
    GROUP_RE    = /\b(the rest|the others|the party|everyone( else)?|they|both|we|us|all of (us|them|us))\b/i
    SHORTCUT_RE = /\A\s*(resolve|go|next|done|nothing)\s*[.!]?\s*\z/i
    DICE_RE     = /\A\s*\d*d\d+([+\-]\d+)?\s*\z/i

    def self.call(**kwargs) = new(**kwargs).call

    def initialize(text:, campaign:, focus_pc: nil, undeclared_pcs: [], undeclared_companions: [])
      @text                 = text.to_s
      @campaign             = campaign
      @focus_pc             = focus_pc
      @undeclared_pcs       = undeclared_pcs
      @undeclared_companions = undeclared_companions
    end

    def call
      return DiceRoll.new(expression: text.strip, pc: dice_default_pc) if text =~ DICE_RE

      if text =~ SHORTCUT_RE
        return shortcut_failure if @undeclared_pcs.any?
        return Failure.new(reason: CollectionPrompt.short_circuit_decline(@undeclared_pcs.map(&:name)))
      end

      # Group/anaphoric words take priority over named PC matching when undeclared characters exist
      if text =~ GROUP_RE && (@undeclared_pcs.any? || @undeclared_companions.any?)
        decls = (@undeclared_pcs + @undeclared_companions).map { { pc: _1, text: text } }
        return Success.new(declarations: decls)
      end

      unknown = unknown_names
      return Failure.new(reason: CollectionPrompt.unknown_pc(unknown.first)) if unknown.any?

      named = matched_names
      return build_named_declarations(named) if named.any?

      return Success.new(declarations: [ { pc: default_target, text: text } ]) if default_target

      Failure.new(reason: CollectionPrompt.no_focus_no_main)
    end

    private

    attr_reader :text

    def all_party = @all_party ||= @campaign.player_characters.to_a

    def matched_names
      all_party.select { name_present?(_1.name) }
    end

    def unknown_names
      # Capitalized whole-word tokens that aren't a party member's name or common English words
      common = %w[I The And A But Or So Then With At In On To For Of From By As Is It If]
      caps = text.scan(/\b[A-Z][a-z]+\b/)
      caps.reject { |w| all_party.any? { _1.name.casecmp(w).zero? } || common.include?(w) }
    end

    def name_present?(name)
      text =~ /\b#{Regexp.escape(name)}\b/i
    end

    def build_named_declarations(pcs)
      sentences = text.split(/(?<=[.!?])\s+/)
      if pcs.size > 1 && sentences.size > 1
        decls = sentences.flat_map do |s|
          matched = pcs.select { |p| s =~ /\b#{Regexp.escape(p.name)}\b/i }
          matched.map { { pc: _1, text: s.strip } }
        end
        return Success.new(declarations: decls.uniq { _1[:pc].id })
      end
      Success.new(declarations: pcs.map { { pc: _1, text: text } })
    end

    def default_target = @focus_pc || @campaign.main_character

    def dice_default_pc = @focus_pc || @campaign.main_character

    def shortcut_failure
      Failure.new(reason: CollectionPrompt.short_circuit_decline(@undeclared_pcs.map(&:name)))
    end
  end
end
