class Npc < ApplicationRecord
  belongs_to :campaign

  validates :name, presence: true, length: { maximum: 100 }
end
