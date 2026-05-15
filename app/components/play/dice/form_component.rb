module Play
  module Dice
    class FormComponent < ViewComponent::Base
      DIE_CHIPS = %w[d4 d6 d8 d10 d12 d20 d100].freeze

      MODIFIER_CHIPS = [
        { key: "plus",  label: "+",     action: "bumpModifier", params: { delta: 1 } },
        { key: "minus", label: "−",     action: "bumpModifier", params: { delta: -1 } },
        { key: "adv",   label: "adv",   action: "setMode",      params: { mode: "adv" } },
        { key: "dis",   label: "dis",   action: "setMode",      params: { mode: "dis" } },
        { key: "clear", label: "clear", action: "clearAll",     params: {} }
      ].freeze

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

      def die_chips
        DIE_CHIPS
      end

      def modifier_chips
        MODIFIER_CHIPS
      end
    end
  end
end
