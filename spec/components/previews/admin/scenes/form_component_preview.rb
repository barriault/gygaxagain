module Admin
  module Scenes
    class FormComponentPreview < ViewComponent::Preview
      def new_scene
        campaign = Campaign.new(id: 1)
        scene = Scene.new(campaign: campaign)
        render Admin::Scenes::FormComponent.new(campaign: campaign, scene: scene)
      end

      def editing_scene
        campaign = Campaign.new(id: 1)
        scene = Scene.new(id: 2, campaign: campaign, title: "Existing scene", summary: "Has a summary.")
        scene.define_singleton_method(:persisted?) { true }
        render Admin::Scenes::FormComponent.new(campaign: campaign, scene: scene)
      end

      def with_errors
        campaign = Campaign.new(id: 1)
        scene = Scene.new(campaign: campaign, title: "")
        scene.valid?
        render Admin::Scenes::FormComponent.new(campaign: campaign, scene: scene)
      end
    end
  end
end
