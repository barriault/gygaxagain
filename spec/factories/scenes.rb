FactoryBot.define do
  factory :scene do
    campaign
    sequence(:title) { |n| "Scene #{n}" }
    summary { "A short scene summary." }
    # position auto-assigned by acts_as_list
  end
end
