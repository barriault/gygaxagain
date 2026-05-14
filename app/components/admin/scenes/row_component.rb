module Admin
  module Scenes
    class RowComponent < ViewComponent::Base
      def initialize(scene:)
        @scene = scene
      end

      attr_reader :scene

      def campaign
        scene.campaign
      end

      def first?
        scene.first?
      end

      def last?
        scene.last?
      end
    end
  end
end
