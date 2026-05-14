# == Schema Information
#
# Table name: scene_audits
#
#  id          :bigint           not null, primary key
#  result      :jsonb            not null
#  verdict     :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  llm_call_id :bigint           not null
#  scene_id    :bigint           not null
#
# Indexes
#
#  index_scene_audits_on_llm_call_id  (llm_call_id)
#  index_scene_audits_on_scene_id     (scene_id) UNIQUE
#  index_scene_audits_on_verdict      (verdict)
#
# Foreign Keys
#
#  fk_rails_...  (llm_call_id => llm_calls.id) ON DELETE => restrict
#  fk_rails_...  (scene_id => scenes.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe SceneAudit do
  describe "validations" do
    it "is valid with a verdict and a scene" do
      audit = build(:scene_audit)
      expect(audit).to be_valid
    end

    it "requires a verdict" do
      audit = build(:scene_audit, verdict: nil)
      expect(audit).not_to be_valid
    end

    it "requires verdict to be one of pass/concerns/fail" do
      audit = build(:scene_audit, verdict: "nonsense")
      expect(audit).not_to be_valid
      expect(audit.errors[:verdict]).to be_present
    end

    it "enforces one audit per scene" do
      audit = create(:scene_audit)
      duplicate = build(:scene_audit, scene: audit.scene)
      expect(duplicate).not_to be_valid
    end
  end

  describe "associations" do
    it "belongs to a scene" do
      audit = create(:scene_audit)
      expect(audit.scene).to be_a(Scene)
    end

    it "belongs to an llm_call" do
      audit = create(:scene_audit)
      expect(audit.llm_call).to be_a(LlmCall)
    end
  end

  describe "cascading delete from scene" do
    it "is removed when its scene is destroyed" do
      audit = create(:scene_audit)
      expect { audit.scene.destroy }.to change(SceneAudit, :count).by(-1)
    end
  end
end
