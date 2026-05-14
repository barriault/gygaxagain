module Llm
  class DiagnosticsForm
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :prompt,        :string
    attribute :system_prompt, :string
    attribute :model,         :string

    validates :prompt, presence: true
    validates :model,  presence: true,
                       inclusion: { in: ->(_form) { Llm::Pricing.known_models },
                                    allow_blank: true,
                                    message: "is not a known model" }
  end
end
