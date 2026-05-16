require "rails_helper"

RSpec.describe "Play::PcDeclarations", type: :request do
  include ActiveJob::TestHelper

  let(:user)     { create(:user) }
  let(:campaign) { create(:campaign, user:) }
  let!(:aragorn) { create(:player_character, campaign:, name: "Aragorn", role: "pc") }
  let!(:caine)   { create(:player_character, campaign:, name: "Caine",   role: "companion") }
  before         { campaign.update!(main_character: aragorn) }
  let(:scene)    { create(:scene, campaign:) }
  let(:path)     { "/campaigns/#{campaign.id}/scenes/#{scene.id}/pc_declarations" }

  before { sign_in user }

  describe "POST /campaigns/:campaign_id/scenes/:scene_id/pc_declarations" do
    it "creates a pc_declaration event attributed to the main PC for unattributed text" do
      expect {
        post path, params: { text: "I push the door open." }
      }.to change { scene.events.where(kind: "pc_declaration").count }.by(1)

      decl = scene.events.where(kind: "pc_declaration").last
      expect(decl.pc).to eq(aragorn)
      expect(decl.payload["text"]).to eq("I push the door open.")
    end

    it "creates a dice_roll event when input matches dice expression" do
      expect {
        post path, params: { text: "1d20+3" }
      }.to change { scene.events.where(kind: "dice_roll").count }.by(1)
    end

    it "creates a gm_collection_prompt and re-prompts on unknown PC" do
      expect {
        post path, params: { text: "Boromir charges" }
      }.to change { scene.events.where(kind: "gm_collection_prompt").count }.by(1)

      prompt = scene.events.where(kind: "gm_collection_prompt").last
      expect(prompt.payload["text"]).to include("Boromir")
    end

    it "enqueues a NarrationJob when all PCs declared and companion check satisfied (no companions)" do
      campaign.player_characters.companions.destroy_all
      expect {
        post path, params: { text: "I look around." }
      }.to have_enqueued_job(NarrationJob).with(hash_including(trigger: "resolution"))
    end

    it "emits a companion_check gm_collection_prompt after main PC declares (companions exist)" do
      expect {
        post path, params: { text: "I look around." }
      }.to change { scene.events.where(kind: "gm_collection_prompt").count }.by(1)

      prompt = scene.events.where(kind: "gm_collection_prompt").last
      expect(prompt.payload["kind"]).to eq("companion_check")
    end
  end
end
