# == Schema Information
#
# Table name: npc_secrets
#
#  id         :bigint           not null, primary key
#  content    :text             not null
#  label      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  npc_id     :bigint           not null
#
# Indexes
#
#  index_npc_secrets_on_npc_id  (npc_id)
#
# Foreign Keys
#
#  fk_rails_...  (npc_id => npcs.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :npc_secret do
    npc
    sequence(:label) { |n| "Hidden NPC fact #{n}" }
    content { "This is hidden content the player must not see." }
  end
end
