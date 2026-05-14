module Play
  module Scenes
    class InputDockComponent < ViewComponent::Base
      def initialize(scene:)
        @scene = scene
      end

      attr_reader :scene
    end
  end
end
