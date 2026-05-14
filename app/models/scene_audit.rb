# == Schema Information
#
# Table name: scene_audits
#
#  id          :bigint           not null, primary key
#  result      :jsonb            not null
#  verdict     :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  llm_call_id :bigint           not null
#  scene_id    :bigint           not null
#
# Indexes
#
#  index_scene_audits_on_llm_call_id  (llm_call_id)
#  index_scene_audits_on_scene_id     (scene_id) UNIQUE
#  index_scene_audits_on_verdict      (verdict)
#
# Foreign Keys
#
#  fk_rails_...  (llm_call_id => llm_calls.id) ON DELETE => restrict
#  fk_rails_...  (scene_id => scenes.id) ON DELETE => cascade
#
class SceneAudit < ApplicationRecord
  belongs_to :scene
  belongs_to :llm_call

  VERDICTS = %w[pass concerns fail].freeze

  validates :verdict, presence: true, inclusion: { in: VERDICTS }
  validates :scene_id, uniqueness: true
end
