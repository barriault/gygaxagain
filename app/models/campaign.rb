# == Schema Information
#
# Table name: campaigns
#
#  id          :bigint           not null, primary key
#  description :text
#  name        :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  user_id     :bigint           not null
#
# Indexes
#
#  index_campaigns_on_user_id           (user_id)
#  index_campaigns_on_user_id_and_name  (user_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class Campaign < ApplicationRecord
  belongs_to :user

  validates :name, presence: true,
                   length: { maximum: 100 },
                   uniqueness: { scope: :user_id }
end
