# == Schema Information
#
# Table name: scene_secrets
#
#  id         :bigint           not null, primary key
#  content    :text             not null
#  label      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  scene_id   :bigint           not null
#
# Indexes
#
#  index_scene_secrets_on_scene_and_label  (scene_id, lower((label)::text)) UNIQUE
#  index_scene_secrets_on_scene_id         (scene_id)
#
# Foreign Keys
#
#  fk_rails_...  (scene_id => scenes.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe SceneSecret, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:scene) }
  end

  describe "validations" do
    subject { build(:scene_secret) }
    it { is_expected.to validate_presence_of(:label) }
    it { is_expected.to validate_presence_of(:content) }
    it { is_expected.to validate_length_of(:label).is_at_most(100) }
    it { is_expected.to validate_uniqueness_of(:label).scoped_to(:scene_id).case_insensitive }
  end

  describe "cascade delete from scene" do
    it "destroys with the scene" do
      scene  = create(:scene)
      secret = create(:scene_secret, scene:)
      expect { scene.destroy }.to change { SceneSecret.where(id: secret.id).count }.from(1).to(0)
    end
  end
end
