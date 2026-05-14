module Play
  module Events
    class OracleQueryComponentPreview < ViewComponent::Preview
      def default
        event = Event.new(
          kind: "oracle_query",
          payload: {
            "question"   => "Is it raining?",
            "likelihood" => "even_odds",
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
            "likelihood" => "even_odds",
            "chaos"      => 3,
            "answer"     => "exceptional no"
          },
          occurred_at: Time.current
        )
        render Play::Events::OracleQueryComponent.new(event: event)
      end
    end
  end
end
