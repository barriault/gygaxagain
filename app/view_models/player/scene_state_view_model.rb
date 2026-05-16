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
      return :idle          if last_narration_handoff?
      :collecting
    end

    def ready_to_resolve?
      phase == :collecting && undeclared_pcs_this_turn.empty? && companion_prompt_offered?
    end

    def current_turn_number
      return 1 if events.empty?
      events.maximum(:turn_number) || 1
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
      events.to_a.reverse.find { _1.kind == "narration" }
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
