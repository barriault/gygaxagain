class Event < ApplicationRecord
  KINDS = %w[narration dice_roll oracle_query scene_transition].freeze

  belongs_to :scene

  enum :kind, KINDS.index_with(&:itself)

  before_validation :default_occurred_at, on: :create
  validates :occurred_at, presence: true

  private

  def default_occurred_at
    self.occurred_at ||= Time.current
  end
end
