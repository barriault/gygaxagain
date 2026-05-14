module Admin
  module Diagnostics
    module Llm
      class ShowComponent < ViewComponent::Base
        def initialize(form:, last_call:)
          @form      = form
          @last_call = last_call
        end

        attr_reader :form, :last_call

        def model_options
          ::Llm::Pricing.known_models
        end
      end
    end
  end
end
