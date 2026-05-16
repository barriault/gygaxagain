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
  KINDS = %w[narration pc_declaration gm_collection_prompt dice_roll scene_transition].freeze

  belongs_to :scene
  belongs_to :pc, class_name: "PlayerCharacter", optional: true

  enum :kind, KINDS.index_with(&:itself)

  before_validation :default_occurred_at, on: :create
  validates :occurred_at, presence: true

  after_create_commit :broadcast_append_to_play_surface

  private

  def default_occurred_at
    self.occurred_at ||= Time.current
  end

  # Push the new event element into the play surface's turbo-frame so
  # subscribed browsers see it immediately, without a page reload.
  #
  # NarrationJob's per-flush `broadcast_replace_to` only works when the
  # target element already exists in the DOM. For events created AFTER
  # initial page render (declarations, collection prompts, resolution
  # narrations triggered by PcDeclarationsController/DiceRollsController),
  # nothing would push them to the browser without this append.
  #
  # The framing narration (created by ScenesController#play before the
  # response renders) is already in the DOM at page load, so the append
  # here is redundant for that one — but it's harmless: the append fires
  # before subscribers exist on first load.
  def broadcast_append_to_play_surface
    return unless scene&.persisted?
    user = scene.campaign&.user
    return unless user

    stream_key = [ scene, user ]

    # Remove the empty-state placeholder if present (no-op when absent).
    Turbo::StreamsChannel.broadcast_remove_to(
      stream_key,
      target: ActionView::RecordIdentifier.dom_id(scene, :log_empty)
    )

    component_class = Play::Events::Component.for(self)
    Turbo::StreamsChannel.broadcast_append_to(
      stream_key,
      target: ActionView::RecordIdentifier.dom_id(scene, :log),
      renderable: component_class.new(event: self),
      layout: false
    )
  end
end
