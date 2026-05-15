module Play
  module Narration
    class FormComponent < ViewComponent::Base
      def initialize(scene:, text: "", error: nil)
        @scene = scene
        @text  = text.to_s
        @error = error
      end

      attr_reader :scene, :text, :error

      def form_dom_id
        helpers.dom_id(scene, :narration_form)
      end

      def submit_path
        helpers.campaign_scene_narrations_path(scene.campaign, scene)
      end
    end
  end
end
