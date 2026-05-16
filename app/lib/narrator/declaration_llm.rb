module Narrator
  # LLM-backed replacement for the regex-based DeclarationParser.
  #
  # Fast paths (no LLM cost) for trivial inputs:
  #   - bare dice expressions ("1d20+3") → DiceRoll
  #   - shortcut words alone ("go", "resolve", "next") → Failure or pass-through
  #
  # For everything else, calls Haiku with a tool-use schema that returns
  # either:
  #   - declarations: [{pc_name, text}, ...]
  #   - or a clarify reason ("I don't see X in the party")
  #
  # Returns the same DeclarationParser::Success / Failure / DiceRoll result
  # types as the old parser, so the controller doesn't change.
  class DeclarationLlm
    DICE_RE     = /\A\s*\d*d\d+([+\-]\d+)?\s*\z/i
    SHORTCUT_RE = /\A\s*(resolve|go|next|done|nothing)\s*[.!]?\s*\z/i

    Success  = DeclarationParser::Success
    Failure  = DeclarationParser::Failure
    DiceRoll = DeclarationParser::DiceRoll

    def self.call(**kwargs) = new(**kwargs).call

    def initialize(text:, campaign:, focus_pc: nil, undeclared_pcs: [], undeclared_companions: [],
                   user: nil, scene: nil)
      @text                  = text.to_s.strip
      @campaign              = campaign
      @focus_pc              = focus_pc
      @undeclared_pcs        = undeclared_pcs
      @undeclared_companions = undeclared_companions
      @user                  = user
      @scene                 = scene
    end

    def call
      return DiceRoll.new(expression: @text, pc: dice_default_pc) if @text =~ DICE_RE

      if @text =~ SHORTCUT_RE
        return Failure.new(reason: CollectionPrompt.short_circuit_decline(@undeclared_pcs.map(&:name))) if @undeclared_pcs.any?
        # All PCs declared. "go" / "resolve" means "skip companion declarations" — treat as
        # empty success so the controller's advance_turn proceeds to companion check / resolution.
        return Success.new(declarations: [])
      end

      result = invoke_llm
      result || Failure.new(reason: CollectionPrompt.no_focus_no_main)
    end

    private

    def invoke_llm
      llm = Llm::Call.execute(
        purpose:    :declaration_parsing,
        system:     [ { type: "text", text: system_prompt } ],
        messages:   [ { role: "user", content: @text } ],
        max_tokens: 600,
        tools:      tool_schema,
        tool_choice: { type: "any" }, # force the model to call one of our tools
        user:       @user,
        campaign:   @campaign,
        scene:      @scene
      )

      tool_use = extract_tool_use(llm)
      return nil unless tool_use

      case tool_use["name"]
      when "declare"
        decls = Array(tool_use.dig("input", "declarations")).filter_map do |d|
          pc = all_party.find { _1.name.casecmp(d["pc_name"].to_s).zero? }
          next nil unless pc
          { pc: pc, text: d["text"].to_s }
        end
        return Failure.new(reason: CollectionPrompt.no_focus_no_main) if decls.empty?
        Success.new(declarations: decls)
      when "clarify"
        Failure.new(reason: tool_use.dig("input", "reason").to_s.presence || CollectionPrompt.no_focus_no_main)
      end
    rescue StandardError => e
      Rails.logger.error("[DeclarationLlm] #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
      nil
    end

    def extract_tool_use(llm)
      blocks = llm.response_payload.dig("content") || []
      blocks.find { _1["type"] == "tool_use" }
    end

    def all_party = @all_party ||= @campaign.player_characters.to_a

    def main_character_name = @campaign.main_character&.name

    def dice_default_pc = @focus_pc || @campaign.main_character

    def system_prompt
      <<~PROMPT
        You parse a player's chat message into per-PC declarations for a solo D&D-style game. The player is one human controlling the whole party. They are now declaring what their character(s) do this turn.

        # Party in this campaign

        - Main PC (the protagonist; default subject when nothing is named): #{main_character_name || "(none — every action must name a PC)"}
        - PCs (player-voiced; player declares for these every turn): #{pc_names_list}
        - Companions (DM-voiced by default; player may override): #{companion_names_list}

        # State this turn

        - PCs who still need a declaration this turn: #{names(@undeclared_pcs)}
        - Companions who still need a declaration this turn: #{names(@undeclared_companions)}
        - PC the DM most recently addressed (use as default if main PC is already declared and input is unattributed): #{@focus_pc&.name || "none"}

        # Rules

        1. Split the player's input into per-PC declarations. Call the `declare` tool with an array of `{pc_name, text}` objects.
        2. A sentence that names a specific PC → declaration for that PC. The text should be that sentence (cleaned up to be natural English, but preserving the player's intent and any dialogue verbatim).
        3. A sentence that names multiple PCs doing one collective action ("Aragorn, Caine, Fred, and Patric enter the tomb") → ONE declaration for the main PC ("Aragorn and the party enter the tomb") plus a companion-summary declaration like "follows Aragorn into the tomb" for each named companion. Don't duplicate the full text verbatim across four PCs.
        4. "Everyone else", "the rest", "the others", "the party" → companions only (the speaker is the main PC and is implicitly the subject of the rest of the input).
        5. "Everyone", "we", "us", "all of us" → all undeclared characters (PCs + companions). Same caveat as rule 3 — don't duplicate text; write per-PC declarations that read naturally.
        6. "they", "both" → undeclared companions, not the main PC.
        7. Unattributed input ("opens the door", "asks the captain about X") with main PC undeclared → declaration for the main PC.
        8. Unattributed input with main PC already declared and a focus PC set → declaration for the focus PC.
        9. If the player names a character who isn't in the party → call `clarify` with reason like "I don't see X in the party. Did you mean Y?"
        10. If the input is genuinely ambiguous (can't tell who's doing what) → call `clarify` with a brief question.

        # Style

        Write each declaration's `text` as a clean, third-person past-tense narration of intent, not the player's literal first-person input. For example: player types "I push the door open" → text "Aragorn pushes the door open". Player types "Caine listens" → text "Caine listens at the door". This keeps the resolution narration coherent with the declaration.

        # Output

        ALWAYS call either `declare` or `clarify`. Never respond with plain text.
      PROMPT
    end

    def pc_names_list
      @undeclared_pcs.empty? && all_party.none? { _1.role == "pc" } ? "(none)" : all_party.select { _1.role == "pc" }.map(&:name).join(", ")
    end

    def companion_names_list
      all_party.select { _1.role == "companion" }.map(&:name).join(", ").presence || "(none)"
    end

    def names(list)
      list.empty? ? "(none — all declared)" : list.map(&:name).join(", ")
    end

    def tool_schema
      [
        {
          name: "declare",
          description: "Record one or more per-PC declarations for this turn.",
          input_schema: {
            type: "object",
            properties: {
              declarations: {
                type:  "array",
                items: {
                  type: "object",
                  properties: {
                    pc_name: { type: "string", description: "Exact name of a PC or companion in the party." },
                    text:    { type: "string", description: "Third-person narration of the PC's intent for this turn." }
                  },
                  required: [ "pc_name", "text" ]
                }
              }
            },
            required: [ "declarations" ]
          }
        },
        {
          name: "clarify",
          description: "Ask the player to clarify when their input names a character not in the party or is genuinely ambiguous.",
          input_schema: {
            type: "object",
            properties: {
              reason: { type: "string", description: "Short message to show the player explaining what's unclear." }
            },
            required: [ "reason" ]
          }
        }
      ]
    end
  end
end
