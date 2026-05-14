module Play
  module Events
    class OracleQueryComponentPreview < ViewComponent::Preview
      def default
        event = Event.new(
          kind: "oracle_query",
          payload: {
            "question"   => "Is it raining?",
            "likelihood" => "50_50",
            "chaos"      => 5,
            "answer"     => "yes"
          },
          occurred_at: Time.current
        )
        render Play::Events::OracleQueryComponent.new(event: event)
      end

      def exceptional_yes
        event = Event.new(
          kind: "oracle_query",
          payload: {
            "question"   => "Does the stranger reveal himself?",
            "likelihood" => "unlikely",
            "chaos"      => 7,
            "answer"     => "exceptional yes"
          },
          occurred_at: Time.current
        )
        render Play::Events::OracleQueryComponent.new(event: event)
      end

      def exceptional_no
        event = Event.new(
          kind: "oracle_query",
          payload: {
            "question"   => "Does the door open?",
            "likelihood" => "50_50",
            "chaos"      => 3,
            "answer"     => "exceptional no"
          },
          occurred_at: Time.current
        )
        render Play::Events::OracleQueryComponent.new(event: event)
      end

      def with_random_event
        campaign = Campaign.new(name: "Preview", chaos_factor: 5)
        scene = Scene.new(id: 1, title: "Preview Scene", campaign: campaign)
        event = Event.new(
          scene: scene,
          kind: "oracle_query",
          occurred_at: Time.current,
          payload: {
            "question"               => "Does the door open?",
            "answer"                 => "Yes",
            "likelihood"             => "50_50",
            "chaos"                  => 5,
            "outcome"                => "yes",
            "roll"                   => 33,
            "random_event_triggered" => true
          }
        )
        render Play::Events::OracleQueryComponent.new(event: event)
      end
    end
  end
end
