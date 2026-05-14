module Play
  module Oracle
    class FormComponentPreview < ViewComponent::Preview
      def default
        scene = preview_scene(chaos: 5)
        render Play::Oracle::FormComponent.new(scene: scene)
      end

      def with_sticky_value
        scene = preview_scene(chaos: 5)
        render Play::Oracle::FormComponent.new(
          scene: scene,
          question: "Does the door open?",
          likelihood: "likely"
        )
      end

      def with_error
        scene = preview_scene(chaos: 5)
        render Play::Oracle::FormComponent.new(
          scene: scene,
          question: "",
          error: "enter a question"
        )
      end

      def with_high_chaos
        scene = preview_scene(chaos: 9)
        render Play::Oracle::FormComponent.new(scene: scene)
      end

      private

      def preview_scene(chaos:)
        campaign = Campaign.new(name: "Preview Campaign", chaos_factor: chaos)
        Scene.new(id: 1, title: "Preview Scene", campaign: campaign)
      end
    end
  end
end
