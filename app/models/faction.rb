class Faction < ApplicationRecord
  belongs_to :campaign

  validates :name, presence: true,
                   length: { maximum: 100 },
                   uniqueness: { scope: :campaign_id, case_sensitive: false }
end
