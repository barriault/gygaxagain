module Narrator
  class PromptBuilder
    RECENT_EVENT_WINDOW = 30

    def self.call(scene:, player_action_text:)
      new(scene: scene, player_action_text: player_action_text).call
    end

    def initialize(scene:, player_action_text:)
      @scene = scene
      @player_action_text = player_action_text.to_s
    end

    def call
      Narrator::Prompt.new(
        system: build_system_blocks,
        messages: build_messages,
        cache_breakpoints: [ 0, 1 ]
      )
    end

    def input_view_models
      [ campaign_vm, scene_vm, *faction_vms, *npc_vms ]
    end

    private

    def build_system_blocks
      [
        { type: "text", text: Narrator::SystemPrompt.text },
        { type: "text", text: campaign_and_roster_text },
        { type: "text", text: scene_context_text }
      ]
    end

    def build_messages
      [ { role: "user", content: @player_action_text } ]
    end

    def campaign_and_roster_text
      <<~MD.strip
        # Campaign

        Name: #{campaign_vm.name}
        #{campaign_vm.description}

        # Factions

        #{faction_vms.map { faction_md(_1) }.join("\n\n")}

        # NPCs

        #{npc_vms.map { npc_md(_1) }.join("\n\n")}
      MD
    end

    def scene_context_text
      <<~MD.strip
        # Current scene

        Title: #{scene_vm.title}
        #{scene_vm.summary}

        # Recent events (oldest first)

        #{recent_events_md}
      MD
    end

    def recent_events_md
      events = recent_events_window
      lines = []
      lines << "[#{omitted_count} earlier events truncated for context]" if omitted_count.positive?
      lines.concat(events.map { event_md(_1) })
      lines.join("\n\n")
    end

    def recent_events_window
      @recent_events_window ||= scene_vm.events.last(RECENT_EVENT_WINDOW)
    end

    def omitted_count
      [ scene_vm.events.size - RECENT_EVENT_WINDOW, 0 ].max
    end

    def event_md(event_vm)
      "[#{event_vm.kind} @ #{event_vm.occurred_at_label}] #{event_vm.text}"
    end

    def faction_md(vm)
      "## #{vm.name}\n#{vm.public_description}"
    end

    def npc_md(vm)
      base = "## #{vm.name}\n#{vm.public_description}"
      vm.location.present? ? "#{base} (#{vm.location})" : base
    end

    def campaign_vm
      @campaign_vm ||= Player::CampaignViewModel.new(@scene.campaign)
    end

    def scene_vm
      @scene_vm ||= Player::SceneViewModel.new(@scene)
    end

    def faction_vms
      @faction_vms ||= @scene.campaign.factions.order(:name).map { Player::FactionViewModel.new(_1) }
    end

    def npc_vms
      @npc_vms ||= @scene.campaign.npcs.order(:name).map { Player::NpcViewModel.new(_1) }
    end
  end
end
