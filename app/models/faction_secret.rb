class FactionSecret < ApplicationRecord
  belongs_to :faction

  validates :label,   presence: true, length: { maximum: 100 }
  validates :content, presence: true
end
