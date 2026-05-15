module Admin
  module Scenes
    class CloseButtonComponentPreview < ViewComponent::Preview
      def available
        scene = Scene.new(id: 1, title: "T", campaign: Campaign.new(id: 1))
        render(Admin::Scenes::CloseButtonComponent.new(scene: scene))
      end

      def disabled_already_closed
        scene = Scene.new(id: 1, title: "T", closed_at: Time.current,
                          campaign: Campaign.new(id: 1))
        render(Admin::Scenes::CloseButtonComponent.new(scene: scene))
      end
    end
  end
end
