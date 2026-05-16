module Play
  module Events
    module Component
      REGISTRY = {
        "narration"             => NarrationComponent,
        "pc_declaration"        => PcDeclarationComponent,
        "gm_collection_prompt"  => GmCollectionPromptComponent,
        "dice_roll"             => DiceRollComponent,
        "scene_transition"      => SceneTransitionComponent
      }.freeze

      def self.for(event)
        REGISTRY.fetch(event.kind) do
          raise ArgumentError, "no component registered for event kind #{event.kind.inspect}"
        end
      end
    end
  end
end
