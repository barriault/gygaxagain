module Admin
  module Scenes
    class RowComponentPreview < ViewComponent::Preview
      def default
        campaign = Campaign.new(id: 1)
        scene = Scene.new(id: 2, campaign: campaign, title: "Middle scene", summary: "A scene in the middle.", position: 2)
        scene.define_singleton_method(:first?) { false }
        scene.define_singleton_method(:last?) { false }
        render(Admin::Scenes::RowComponent.new(scene: scene), layout: false)
      end

      def first_position
        campaign = Campaign.new(id: 1)
        scene = Scene.new(id: 1, campaign: campaign, title: "First scene", summary: "Cannot move up.", position: 1)
        scene.define_singleton_method(:first?) { true }
        scene.define_singleton_method(:last?) { false }
        render(Admin::Scenes::RowComponent.new(scene: scene), layout: false)
      end

      def last_position
        campaign = Campaign.new(id: 1)
        scene = Scene.new(id: 3, campaign: campaign, title: "Last scene", summary: "Cannot move down.", position: 3)
        scene.define_singleton_method(:first?) { false }
        scene.define_singleton_method(:last?) { true }
        render(Admin::Scenes::RowComponent.new(scene: scene), layout: false)
      end
    end
  end
end
