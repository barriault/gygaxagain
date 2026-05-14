class Scene < ApplicationRecord
  belongs_to :campaign

  acts_as_list scope: :campaign

  validates :title, presence: true, length: { maximum: 100 }
end
