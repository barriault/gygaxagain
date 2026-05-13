# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  current_sign_in_at     :datetime
#  current_sign_in_ip     :string
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  failed_attempts        :integer          default(0), not null
#  last_sign_in_at        :datetime
#  last_sign_in_ip        :string
#  locked_at              :datetime
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  sign_in_count          :integer          default(0), not null
#  unlock_token           :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#  index_users_on_unlock_token          (unlock_token) UNIQUE
#
require "rails_helper"

RSpec.describe User, type: :model do
  describe "Devise modules" do
    it "enables the expected modules" do
      expect(User.devise_modules).to match_array(
        %i[database_authenticatable recoverable rememberable validatable
           trackable timeoutable lockable]
      )
    end

    it "does not enable registerable" do
      expect(User.devise_modules).not_to include(:registerable)
    end

    it "does not enable confirmable" do
      expect(User.devise_modules).not_to include(:confirmable)
    end
  end

  describe "factory" do
    it "creates a persistable user" do
      user = build(:user)
      expect(user).to be_valid
      expect { user.save! }.not_to raise_error
    end
  end
end
