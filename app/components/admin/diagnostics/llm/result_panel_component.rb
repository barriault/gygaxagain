module Admin
  module Diagnostics
    module Llm
      class ResultPanelComponent < ViewComponent::Base
        def initialize(call:)
          @llm_call = call
        end

        attr_reader :llm_call

        def cost_dollars_formatted
          helpers.number_to_currency(llm_call.total_cost_dollars)
        end

        def pretty(payload)
          JSON.pretty_generate(payload)
        end
      end
    end
  end
end
