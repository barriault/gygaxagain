module Play
  module Dice
    class FormComponent < ViewComponent::Base
      QUICK_CHIPS = {
        "d20"  => "1d20",
        "d100" => "1d100",
        "2d6"  => "2d6",
        "adv"  => "2d20kh1",
        "dis"  => "2d20kl1"
      }.freeze

      def initialize(scene:, expression: nil, error: nil)
        @scene = scene
        @expression = expression
        @error = error
      end

      attr_reader :scene, :expression, :error

      def campaign
        scene.campaign
      end

      def container_dom_id
        helpers.dom_id(scene, :dice_form)
      end

      def quick_chips
        QUICK_CHIPS
      end
    end
  end
end
