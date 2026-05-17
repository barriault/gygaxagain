module Player
  class SceneStateViewModel < ApplicationViewModel
    OPEN_CHIP_RE  = /\[\[.*\]\]\s*\z/m
    HANDOFF_RE    = /\?\s*\z/

    def initialize(scene)
      @scene = scene
    end

    def phase
      return :framing if events.empty?
      return :awaiting_roll if last_narration_open_chip?

      # If the most recent narration ended cleanly AND nothing has happened
      # since, we're idle (waiting for the player to start the next turn).
      # If declarations / prompts have been created after that narration,
      # we're collecting for the next turn.
      if last_narration && last_narration_handoff?
        events_arr = events.to_a
        has_events_after = events_arr.any? { |e| e.id > last_narration.id }
        return has_events_after ? :collecting : :idle
      end

      :collecting
    end

    def ready_to_resolve?
      phase == :collecting && undeclared_pcs_this_turn.empty? && companion_prompt_offered?
    end

    # Turn number for the NEXT event about to be created on this scene.
    #
    # Convention: the framing narration sits at turn 0 (system-initiated
    # scene opener, no player input). Player turns are 1, 2, 3...
    #
    # Rules:
    # - If there are events AFTER the last narration, we're mid-turn
    #   (declarations / prompts being collected for the in-flight turn).
    #   Reuse the current max so all of this turn's events share a number.
    # - If the last narration is clean (handoff `?`) and is the most recent
    #   event, we're between turns. The next event starts the next turn
    #   (last narration's turn_number + 1).
    # - If the last narration is in-progress (no handoff yet) and is the
    #   most recent event, we're still in its turn.
    def current_turn_number
      return 1 if events.empty?

      last_n = last_narration
      return 1 unless last_n  # no narration yet — treat first player input as T1

      events_arr = events.to_a
      events_after_last_narration = events_arr.any? { |e| e.id > last_n.id }

      if events_after_last_narration
        events.maximum(:turn_number) || last_n.turn_number.to_i
      elsif last_narration_handoff?
        last_n.turn_number.to_i + 1
      else
        last_n.turn_number.to_i
      end
    end

    def declared_this_turn
      pc_declarations_this_turn.map(&:pc).compact
    end

    def undeclared_pcs_this_turn
      return [] unless phase == :collecting
      campaign.player_characters.pcs.order(:name).reject { declared_this_turn.include?(_1) }
    end

    def undeclared_companions_this_turn
      campaign.player_characters.companions.order(:name).reject { declared_this_turn.include?(_1) }
    end

    def companion_prompt_offered?
      return true if campaign.player_characters.companions.none?
      # All companions already declared → the check would be redundant.
      return true if undeclared_companions_this_turn.empty?
      gm_collection_prompts_this_turn.any? { _1.payload["kind"] == "companion_check" }
    end

    def composer_enabled?
      %i[idle collecting].include?(phase)
    end

    private

    attr_reader :scene

    def campaign = scene.campaign

    def events
      @events ||= scene.events.order(:occurred_at, :id)
    end

    def events_since_last_clean_narration
      idx = events.to_a.rindex { |e| e.kind == "narration" && (e.payload["text"] || "") =~ HANDOFF_RE }
      idx ? events.to_a[(idx + 1)..] : events.to_a
    end

    def pc_declarations_this_turn
      events_since_last_clean_narration.select { _1.kind == "pc_declaration" }
    end

    def gm_collection_prompts_this_turn
      events_since_last_clean_narration.select { _1.kind == "gm_collection_prompt" }
    end

    def last_narration
      # Skip errored narrations: a failed continuation leaves an empty errored
      # event in the log, and treating it as "last narration" would drop the
      # phase out of :awaiting_roll, preventing chip-retry from re-enqueueing.
      events.to_a.reverse.find { _1.kind == "narration" && _1.payload["status"] != "errored" }
    end

    def last_narration_text
      (last_narration&.payload || {})["text"].to_s
    end

    def last_narration_open_chip?
      return false unless last_narration
      last_narration_text =~ OPEN_CHIP_RE
    end

    def last_narration_handoff?
      return false unless last_narration
      last_narration_text =~ HANDOFF_RE
    end
  end
end
