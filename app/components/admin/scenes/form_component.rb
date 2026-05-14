module Admin
  module Scenes
    class FormComponent < ViewComponent::Base
      def initialize(campaign:, scene:)
        @campaign = campaign
        @scene = scene
      end

      attr_reader :campaign, :scene

      def form_url
        if scene.persisted?
          helpers.admin_campaign_scene_path(campaign, scene)
        else
          helpers.admin_campaign_scenes_path(campaign)
        end
      end

      def form_method
        scene.persisted? ? :patch : :post
      end

      def submit_label
        scene.persisted? ? "Update scene" : "Create scene"
      end

      def header
        scene.persisted? ? "Edit scene" : "New scene"
      end
    end
  end
end
