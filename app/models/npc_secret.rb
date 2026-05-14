class NpcSecret < ApplicationRecord
  belongs_to :npc

  validates :label,   presence: true, length: { maximum: 100 }
  validates :content, presence: true
end
