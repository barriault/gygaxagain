module Play
  module Scenes
    class PlayComponent < ViewComponent::Base
      def initialize(scene:)
        @scene = scene
      end

      attr_reader :scene

      def campaign
        scene.campaign
      end
    end
  end
end
