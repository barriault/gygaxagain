module Play
  module Events
    class NarrationComponent < ViewComponent::Base
      def initialize(event:)
        @event = event
      end
      attr_reader :event

      def text       = event.payload["text"].to_s
      def status     = event.payload["status"] || "complete"
      def dom_id     = helpers.dom_id(event)
      def streaming? = status == "streaming"
      def errored?   = status == "errored"

      def error_message
        event.payload["error_message"].to_s
      end

      def relative_time
        helpers.time_ago_in_words(event.occurred_at) + " ago"
      end

      def rendered_html
        chip_data = Narrator::ChipParser.parse(text)
        # Substitute chips with placeholder tokens, render markdown, then swap tokens back in for HTML buttons
        token_map = {}
        text_with_tokens = text.dup
        chip_data.chips.each_with_index do |chip, i|
          token = "{{chip_#{i}}}"
          token_map[token] = chip
          text_with_tokens.sub!(chip[:full], token)
        end
        html = Commonmarker.to_html(text_with_tokens, options: { render: { unsafe: false } })
        token_map.each do |token, chip|
          html = html.sub(token, chip_button_html(chip))
        end
        html.html_safe
      end

      private

      def chip_button_html(chip)
        classes = "dice-chip inline-flex items-center gap-1 rounded border border-amber-700/60 " \
                  "bg-amber-900/30 px-2 py-0.5 text-sm text-amber-200 " \
                  "hover:bg-amber-800/50 hover:border-amber-500 " \
                  "disabled:opacity-50 disabled:cursor-not-allowed " \
                  "transition-colors cursor-pointer"
        %(<button type="button" class="#{classes}" data-controller="dice-chip" ) +
          %(data-dice-chip-expression-value="#{ERB::Util.html_escape(chip[:expression])}" ) +
          %(data-dice-chip-pc-name-value="#{ERB::Util.html_escape(chip[:pc_name])}" ) +
          %(data-dice-chip-reason-value="#{ERB::Util.html_escape(chip[:reason])}" ) +
          %(data-action="click->dice-chip#roll">) +
          %(🎲 <span class="font-mono">#{ERB::Util.html_escape(chip[:expression])}</span> ) +
          %(<span class="text-amber-300/70">— #{ERB::Util.html_escape(chip[:pc_name])} #{ERB::Util.html_escape(chip[:reason])}</span>) +
          %(</button>)
      end
    end
  end
end
