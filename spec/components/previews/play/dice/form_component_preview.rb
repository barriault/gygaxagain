module Play
  module Dice
    class FormComponentPreview < ViewComponent::Preview
      def default
        scene = preview_scene
        render Play::Dice::FormComponent.new(scene: scene)
      end

      def with_error
        scene = preview_scene
        render Play::Dice::FormComponent.new(
          scene: scene,
          expression: "1d6+wat",
          error: "unparseable at position 4"
        )
      end

      private

      def preview_scene
        campaign = Campaign.new(name: "Preview Campaign", chaos_factor: 5)
        Scene.new(id: 1, title: "Preview Scene", campaign: campaign)
      end
    end
  end
end
