module Narrator
  class AuditPromptBuilder
    def self.call(scene:)
      new(scene: scene).call
    end

    def initialize(scene:)
      @scene = scene
    end

    def call
      Narrator::Prompt.new(
        system: [ { type: "text", text: Narrator::AuditSystemPrompt.text } ],
        messages: [ { role: "user", content: scene_transcript } ],
        cache_breakpoints: [ 0 ]
      )
    end

    private

    def scene_transcript
      vm = Narrator::SceneAuditViewModel.new(@scene)
      header = "# Scene: #{vm.title}\n\n#{vm.summary}\n\n# Events\n\n"
      header + vm.events.map { event_line(_1) }.join("\n\n")
    end

    def event_line(event_vm)
      "[#{event_vm.kind} @ #{event_vm.occurred_at_label}]\n#{event_vm.text}"
    end
  end
end
