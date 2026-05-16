module Narrator
  class DeclarationParser
    # "Everyone else" / "the rest" / "the others" specifically EXCLUDE the speaker
    # (the main PC / focus). They route to undeclared companions only.
    EXCLUSIVE_GROUP_RE = /\b(the rest|the others|the party|everyone else)\b/i
    # "Everyone" / "We" / "us" / "all of us" / "they" / "both" route to ALL undeclared
    # characters (PCs + companions). Note: place EXCLUSIVE check first so "everyone else"
    # matches the exclusive form before falling through to plain "everyone".
    INCLUSIVE_GROUP_RE = /\b(everyone|we|us|all of (us|them)|they|both)\b/i

    SHORTCUT_RE = /\A\s*(resolve|go|next|done|nothing)\s*[.!]?\s*\z/i
    DICE_RE     = /\A\s*\d*d\d+([+\-]\d+)?\s*\z/i

    def self.call(**kwargs) = new(**kwargs).call

    def initialize(text:, campaign:, focus_pc: nil, undeclared_pcs: [], undeclared_companions: [])
      @text                  = text.to_s
      @campaign              = campaign
      @focus_pc              = focus_pc
      @undeclared_pcs        = undeclared_pcs
      @undeclared_companions = undeclared_companions
    end

    def call
      return DiceRoll.new(expression: text.strip, pc: dice_default_pc) if text =~ DICE_RE

      if text =~ SHORTCUT_RE
        return shortcut_failure if @undeclared_pcs.any?
        return Failure.new(reason: CollectionPrompt.short_circuit_decline(@undeclared_pcs.map(&:name)))
      end

      unknown = unknown_names
      return Failure.new(reason: CollectionPrompt.unknown_pc(unknown.first)) if unknown.any?

      # Per-sentence attribution: each sentence is routed independently. This lets
      # "Ask the captain... Everyone else waits." split correctly — first sentence
      # → main PC, second sentence → companions only.
      sentences = split_sentences(text)
      decls = sentences.flat_map { |s| attribute_sentence(s) }.compact

      # Dedupe: a PC gets only one declaration per turn. Keep the LAST occurrence
      # so "Aragorn looks. Aragorn draws." merges to the second.
      seen = {}
      decls.reverse_each { |d| seen[d[:pc].id] ||= d }
      ordered = decls.uniq { _1[:pc].id }.map { |d| seen[d[:pc].id] }

      return Success.new(declarations: ordered) if ordered.any?

      Failure.new(reason: CollectionPrompt.no_focus_no_main)
    end

    private

    attr_reader :text

    def all_party = @all_party ||= @campaign.player_characters.to_a

    def split_sentences(str)
      parts = str.split(/(?<=[.!?])\s+/).map(&:strip).reject(&:empty?)
      parts.empty? ? [ str ] : parts
    end

    # Returns an Array of { pc:, text: } declarations (possibly empty) for one sentence.
    def attribute_sentence(sentence)
      named = all_party.select { |pc| sentence =~ /\b#{Regexp.escape(pc.name)}\b/i }
      return named.map { |pc| { pc:, text: sentence } } if named.any?

      # Exclusive group ("everyone else", "the rest", etc.) → companions only.
      if sentence =~ EXCLUSIVE_GROUP_RE && @undeclared_companions.any?
        return @undeclared_companions.map { |pc| { pc:, text: sentence } }
      end

      # Inclusive group ("everyone", "we", "they", etc.) → all undeclared.
      if sentence =~ INCLUSIVE_GROUP_RE && (@undeclared_pcs.any? || @undeclared_companions.any?)
        return (@undeclared_pcs + @undeclared_companions).map { |pc| { pc:, text: sentence } }
      end

      # Default: main PC or focus.
      default = default_target
      return [ { pc: default, text: sentence } ] if default
      []
    end

    def unknown_names
      # Capitalized whole-word tokens that aren't a party member's name or common English words.
      # Strip quoted strings first so words inside dialogue ("What else...") don't trigger.
      common = %w[I The And A But Or So Then With At In On To For Of From By As Is It If
                  Ask Tell Look Say Walk Go Come Run Stop Take Give Find See Hear
                  What When Where Why How Who Which Yes No Maybe Please Try
                  This That These Those Here There Now Then Today Tonight Tomorrow]
      stripped = text.gsub(/"[^"]*"/, "").gsub(/'[^']*'/, "")
      caps = stripped.scan(/\b[A-Z][a-z]+\b/)
      caps.reject { |w| all_party.any? { _1.name.casecmp(w).zero? } || common.include?(w) }
    end

    def default_target = @focus_pc || @campaign.main_character

    def dice_default_pc = @focus_pc || @campaign.main_character

    def shortcut_failure
      Failure.new(reason: CollectionPrompt.short_circuit_decline(@undeclared_pcs.map(&:name)))
    end
  end
end
