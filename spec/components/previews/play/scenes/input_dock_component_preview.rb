module Play
  module Scenes
    class InputDockComponentPreview < ViewComponent::Preview
      def default
        campaign = Campaign.new(name: "Preview Campaign", chaos_factor: 5)
        scene = Scene.new(id: 1, title: "Preview Scene", campaign: campaign)
        render Play::Scenes::InputDockComponent.new(scene: scene)
      end
    end
  end
end
