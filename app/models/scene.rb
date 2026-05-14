class Scene < ApplicationRecord
  belongs_to :campaign
  has_many :events, dependent: :destroy

  acts_as_list scope: :campaign

  validates :title, presence: true, length: { maximum: 100 }
end
