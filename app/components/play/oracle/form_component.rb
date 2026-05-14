module Play
  module Oracle
    class FormComponent < ViewComponent::Base
      DEFAULT_LIKELIHOOD = "50_50".freeze

      LIKELIHOOD_LABELS = {
        "impossible"         => "Impossible",
        "nearly_impossible"  => "Nearly impossible",
        "very_unlikely"      => "Very unlikely",
        "unlikely"           => "Unlikely",
        "50_50"              => "50/50",
        "likely"             => "Likely",
        "very_likely"        => "Very likely",
        "nearly_certain"     => "Nearly certain",
        "certain"            => "Certain"
      }.freeze

      def initialize(scene:, question: nil, likelihood: nil, error: nil)
        @scene = scene
        @question = question
        @likelihood = likelihood || DEFAULT_LIKELIHOOD
        @error = error
      end

      attr_reader :scene, :question, :likelihood, :error

      def campaign
        scene.campaign
      end

      def container_dom_id
        helpers.dom_id(scene, :oracle_form)
      end

      def likelihood_options
        LIKELIHOOD_LABELS.map { |value, label| [ label, value ] }
      end
    end
  end
end
