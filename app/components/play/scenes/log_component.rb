module Play
  module Scenes
    class LogComponent < ViewComponent::Base
      def initialize(scene:)
        @scene = scene
      end

      attr_reader :scene

      def events
        @events ||= scene.events.order(:occurred_at)
      end

      def empty?
        events.empty?
      end

      def component_for(event)
        Play::Events::Component.for(event).new(event: event)
      end
    end
  end
end
