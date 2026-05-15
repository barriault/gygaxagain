module Play
  module Narration
    class FormComponentPreview < ViewComponent::Preview
      def default
        scene = Scene.new(id: 1, title: "T", summary: "S", campaign: Campaign.new(id: 1, name: "Demo"))
        render(Play::Narration::FormComponent.new(scene: scene))
      end

      def with_sticky_text
        scene = Scene.new(id: 1, title: "T", summary: "S", campaign: Campaign.new(id: 1, name: "Demo"))
        render(Play::Narration::FormComponent.new(scene: scene, text: "I open the door.", error: nil))
      end

      def with_error
        scene = Scene.new(id: 1, title: "T", summary: "S", campaign: Campaign.new(id: 1, name: "Demo"))
        render(Play::Narration::FormComponent.new(scene: scene, text: " ", error: "type something to do"))
      end
    end
  end
end
