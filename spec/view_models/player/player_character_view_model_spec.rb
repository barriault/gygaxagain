require "rails_helper"

RSpec.describe Player::PlayerCharacterViewModel, type: :view_model do
  let(:campaign) { create(:campaign) }
  let(:pc)       { create(:player_character, campaign:, name: "Aragorn", role: "pc", notes: "SECRET DM NOTE") }

  describe "exposed attributes" do
    subject { described_class.new(pc) }

    it "exposes player-safe fields" do
      expect(subject.to_h).to include(
        id: pc.id,
        name: "Aragorn",
        role: "pc",
        class_name: pc.class_name,
        level: pc.level,
        pronouns: pc.pronouns
      )
    end

    it "does not expose notes" do
      expect(subject.to_h).not_to have_key(:notes)
    end
  end

  describe "asymmetry" do
    before do
      @faction = create(:faction, campaign:)
      create(:faction_secret, faction: @faction, content: "hidden faction info")
      @npc = create(:npc, campaign:)
      create(:npc_secret, npc: @npc, content: "hidden npc info")
      @scene = create(:scene, campaign:)
      create(:scene_secret, scene: @scene, content: "hidden scene info")
    end

    it "does not leak secrets of related records" do
      vm = described_class.new(pc)
      expect(vm).not_to leak_secrets_of(@faction, @npc)
      expect(vm.to_h.to_s).not_to include("SECRET DM NOTE")
    end
  end
end
