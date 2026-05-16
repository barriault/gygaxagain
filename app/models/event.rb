# == Schema Information
#
# Table name: events
#
#  id          :bigint           not null, primary key
#  kind        :string           not null
#  occurred_at :datetime         not null
#  payload     :jsonb            not null
#  turn_number :integer
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  pc_id       :bigint
#  scene_id    :bigint           not null
#
# Indexes
#
#  index_events_on_kind                      (kind)
#  index_events_on_pc_id                     (pc_id)
#  index_events_on_scene_id                  (scene_id)
#  index_events_on_scene_id_and_occurred_at  (scene_id,occurred_at)
#  index_events_on_scene_id_and_turn_number  (scene_id,turn_number)
#
# Foreign Keys
#
#  fk_rails_...  (pc_id => player_characters.id) ON DELETE => nullify
#  fk_rails_...  (scene_id => scenes.id) ON DELETE => cascade
#
class Event < ApplicationRecord
  KINDS = %w[narration player_action dice_roll oracle_query scene_transition].freeze

  belongs_to :scene
  belongs_to :pc, class_name: "PlayerCharacter", optional: true

  enum :kind, KINDS.index_with(&:itself)

  before_validation :default_occurred_at, on: :create
  validates :occurred_at, presence: true

  private

  def default_occurred_at
    self.occurred_at ||= Time.current
  end
end
