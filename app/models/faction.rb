class Faction < ApplicationRecord
  belongs_to :campaign
  has_many :secrets, class_name: "FactionSecret", dependent: :destroy

  validates :name, presence: true,
                   length: { maximum: 100 },
                   uniqueness: { scope: :campaign_id, case_sensitive: false }
end
