module Admin
  module Scenes
    class CloseButtonComponent < ViewComponent::Base
      def initialize(scene:)
        @scene = scene
      end

      attr_reader :scene

      def disabled?
        scene.closed?
      end

      def label
        disabled? ? "Closed" : "End scene"
      end

      def submit_path
        helpers.admin_campaign_scene_closure_path(scene.campaign, scene)
      end
    end
  end
end
