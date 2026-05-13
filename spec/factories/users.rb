# == Schema Information
#
# Table name: users
#
#  id                      :bigint           not null, primary key
#  current_sign_in_at      :datetime
#  current_sign_in_ip      :string
#  email                   :string           default(""), not null
#  encrypted_password      :string           default(""), not null
#  failed_attempts         :integer          default(0), not null
#  last_sign_in_at         :datetime
#  last_sign_in_ip         :string
#  locked_at               :datetime
#  remember_created_at     :datetime
#  reset_password_sent_at  :datetime
#  reset_password_token    :string
#  sign_in_count           :integer          default(0), not null
#  unlock_token            :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  last_played_campaign_id :bigint
#
# Indexes
#
#  index_users_on_email                    (email) UNIQUE
#  index_users_on_last_played_campaign_id  (last_played_campaign_id)
#  index_users_on_reset_password_token     (reset_password_token) UNIQUE
#  index_users_on_unlock_token             (unlock_token) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (last_played_campaign_id => campaigns.id) ON DELETE => nullify
#
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.test" }
    password { "correct horse battery staple" }
    password_confirmation { "correct horse battery staple" }
  end
end
