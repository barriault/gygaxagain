# == Schema Information
#
# Table name: scene_secrets
#
#  id         :bigint           not null, primary key
#  content    :text             not null
#  label      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  scene_id   :bigint           not null
#
# Indexes
#
#  index_scene_secrets_on_scene_and_label  (scene_id, lower((label)::text)) UNIQUE
#  index_scene_secrets_on_scene_id         (scene_id)
#
# Foreign Keys
#
#  fk_rails_...  (scene_id => scenes.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :scene_secret do
    scene
    sequence(:label) { |n| "Encounter map #{n}" }
    content          { "DM-only content for this scene." }
  end
end
