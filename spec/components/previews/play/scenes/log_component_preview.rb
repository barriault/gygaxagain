module Play
  module Scenes
    class LogComponentPreview < ViewComponent::Preview
      def with_one_of_each_kind
        scene = build_scene_with_events(
          [
            { kind: "narration",        payload: { "text" => "The tavern is quiet. Rain drips from the eaves." } },
            { kind: "dice_roll",        payload: { "expression" => "2d6+3", "result" => 10, "breakdown" => [ 4, 3, "+3" ] } },
            { kind: "narration",        payload: { "text" => "You notice a familiar dagger on his belt." } },
            { kind: "oracle_query",     payload: { "question" => "Does he leave?", "likelihood" => "unlikely", "chaos" => 5, "answer" => "no, exceptional" } },
            { kind: "scene_transition", payload: { "reason" => "Player followed the stranger to the forest." } }
          ]
        )
        render Play::Scenes::LogComponent.new(scene: scene)
      end

      def empty
        # Build an unsaved Scene with no events so the empty state renders.
        scene = Scene.new(title: "Empty scene", summary: nil)
        scene.define_singleton_method(:events) { Event.none }
        render Play::Scenes::LogComponent.new(scene: scene)
      end

      private

      def build_scene_with_events(event_specs)
        # In-memory scene + in-memory events for visual review without DB writes.
        scene = Scene.new(title: "Preview scene")
        events = event_specs.map.with_index do |spec, i|
          Event.new(
            scene: scene,
            kind: spec[:kind],
            payload: spec[:payload],
            occurred_at: Time.current - (event_specs.size - i).minutes
          )
        end
        scene.define_singleton_method(:events) do
          Class.new do
            def initialize(records) = @records = records
            def order(*) = self
            def empty? = @records.empty?
            def each(&block) = @records.each(&block)
            def to_a = @records.to_a
            include Enumerable
          end.new(events)
        end
        scene
      end
    end
  end
end
