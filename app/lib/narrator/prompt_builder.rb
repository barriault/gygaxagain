module Narrator
  class PromptBuilder
    STOP_SEQUENCES = [ "]]" ].freeze

    def self.framing(scene:)
      new(scene:, kind: :framing).build
    end

    def self.resolution(scene:, current_turn_declarations:)
      new(scene:, kind: :resolution, current_turn_declarations: current_turn_declarations).build
    end

    def self.continuation(scene:, latest_roll:)
      new(scene:, kind: :continuation, latest_roll: latest_roll).build
    end

    def initialize(scene:, kind:, current_turn_declarations: [], latest_roll: nil)
      @scene = scene
      @kind = kind
      @current_turn_declarations = current_turn_declarations
      @latest_roll = latest_roll
    end

    def build
      msgs = build_messages
      Narrator::Prompt.new(
        system: build_system_blocks,
        messages: msgs,
        cache_breakpoints: build_cache_breakpoints(msgs),
        stop_sequences: STOP_SEQUENCES
      )
    end

    private

    attr_reader :scene, :kind, :current_turn_declarations, :latest_roll

    def campaign = scene.campaign

    # ── System blocks ────────────────────────────────────────────────

    def build_system_blocks
      [
        { type: "text", text: discipline_text },
        { type: "text", text: campaign_text },
        { type: "text", text: scene_text }
      ]
    end

    def discipline_text
      template = Narrator::SystemPrompt.text
      pc_names_str        = campaign_vm.pcs.map(&:name).join(", ").presence || "none"
      companion_names_str = campaign_vm.companions.map(&:name).join(", ").presence || "none"
      template
        .gsub("{pc_names}",        pc_names_str)
        .gsub("{companion_names}", companion_names_str)
    end

    def campaign_text
      [
        "# Campaign",
        "Name: #{campaign_vm.name}",
        campaign_vm.description.to_s,
        "",
        "# Party",
        party_md,
        "",
        "# Factions",
        campaign_vm.factions.map { faction_md(_1) }.join("\n\n").presence || "(none)",
        "",
        "# NPCs",
        campaign_vm.npcs.map { npc_md(_1) }.join("\n\n").presence || "(none)"
      ].join("\n")
    end

    def party_md
      lines = []
      lines << "## PCs"
      campaign_vm.pcs.each { lines << pc_md(_1) }
      lines << "## Companions"
      campaign_vm.companions.each { lines << pc_md(_1) }
      lines.join("\n")
    end

    def pc_md(pc)
      parts = [ "- **#{pc.name}** (#{pc.role}) — #{pc.class_name} #{pc.level}, #{pc.pronouns}" ]
      parts << "  Notes: #{pc.notes}" if pc.notes.present?
      parts.join("\n")
    end

    def faction_md(f)
      lines = [ "## #{f.name}", f.public_description.to_s ]
      f.secrets.each { lines << "- _SECRET (#{_1.label}):_ #{_1.content}" }
      lines.join("\n")
    end

    def npc_md(n)
      lines = [ "## #{n.name}" ]
      lines << "Location: #{n.location}" if n.location.present?
      lines << n.public_description.to_s
      n.secrets.each { lines << "- _SECRET (#{_1.label}):_ #{_1.content}" }
      lines.join("\n")
    end

    def scene_text
      lines = [
        "# Current scene",
        "Title: #{scene_vm.title}",
        scene_vm.summary.to_s
      ]
      if scene_vm.scene_secrets.any?
        lines << ""
        lines << "## DM-only scene notes"
        scene_vm.scene_secrets.each { lines << "- **#{_1.label}**: #{_1.content}" }
      end
      lines.join("\n")
    end

    # ── Messages ─────────────────────────────────────────────────────

    def build_messages
      msgs = completed_turn_messages
      msgs += partial_turn_messages
      cu = current_user_message
      msgs << cu if cu
      msgs.compact
    end

    def completed_turns
      events = scene.events.where(kind: %w[pc_declaration dice_roll narration]).order(:turn_number, :occurred_at, :id)
      events.group_by(&:turn_number).select { |_, evs| evs.any? { _1.kind == "narration" } && handoff?(evs.select { _1.kind == "narration" }.last) }
    end

    def completed_turn_messages
      completed_turns.flat_map do |turn_n, evs|
        [
          { role: "user",      content: user_content_for_turn(turn_n, evs) },
          { role: "assistant", content: assistant_content_for_turn(evs) }
        ]
      end
    end

    def partial_turn_messages
      # Only relevant for continuation kind: include partial narration as last assistant message
      return [] unless kind == :continuation
      partial = scene.events.where(kind: "narration").order(:turn_number, :occurred_at, :id).last
      return [] unless partial
      [ { role: "assistant", content: partial.payload["text"].to_s } ]
    end

    def current_user_message
      case kind
      when :framing
        { role: "user", content: "[Scene start] What does #{main_character_name} do?" }
      when :resolution
        { role: "user", content: "[Turn #{turn_number}]\n" + format_declarations(current_turn_declarations) }
      when :continuation
        roll = latest_roll
        pc_name = roll.pc&.name || "Unknown PC"
        line = "#{pc_name} rolled #{roll.payload['expression']} = #{roll.payload['result']}"
        line += " (#{roll.payload['reason']})" if roll.payload["reason"].present?
        { role: "user", content: line + "." }
      end
    end

    def user_content_for_turn(turn_n, evs)
      declarations = evs.select { _1.kind == "pc_declaration" }
      rolls        = evs.select { _1.kind == "dice_roll" }
      lines = [ "[Turn #{turn_n}]" ]
      declarations.each { lines << "#{_1.pc.name} declares: #{_1.payload['text']}" }
      rolls.each do |r|
        line = "#{r.pc&.name || 'Unknown PC'} rolled #{r.payload['expression']} = #{r.payload['result']}"
        line += " (#{r.payload['reason']})" if r.payload["reason"].present?
        lines << line + "."
      end
      lines.join("\n")
    end

    def assistant_content_for_turn(evs)
      evs.select { _1.kind == "narration" }.map { _1.payload["text"].to_s }.join("\n\n")
    end

    def format_declarations(decls)
      decls.map { "#{_1[:pc].name} declares: #{_1[:text]}" }.join("\n")
    end

    def handoff?(narration_event)
      narration_event.payload["text"].to_s =~ /\?\s*\z/
    end

    def turn_number
      Player::SceneStateViewModel.new(scene).current_turn_number
    end

    def main_character_name
      campaign.main_character&.name || "the party"
    end

    # ── Cache breakpoints ────────────────────────────────────────────

    def build_cache_breakpoints(msgs)
      bps = [ 0, 1, 2 ]
      assistant_count = msgs.count { _1[:role] == "assistant" }
      bps << -2 if assistant_count >= 1
      bps
    end

    # ── View models ──────────────────────────────────────────────────

    def campaign_vm = @campaign_vm ||= Narrator::CampaignViewModel.new(campaign)
    def scene_vm    = @scene_vm    ||= Narrator::SceneViewModel.new(scene)
  end
end
