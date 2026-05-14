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

      def frame_dom_id
        helpers.dom_id(scene, :log)
      end

      def empty_state_dom_id
        helpers.dom_id(scene, :log_empty)
      end
    end
  end
end
