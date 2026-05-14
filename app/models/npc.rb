class Npc < ApplicationRecord
  belongs_to :campaign
  has_many :secrets, class_name: "NpcSecret", dependent: :destroy

  validates :name, presence: true, length: { maximum: 100 }
end
