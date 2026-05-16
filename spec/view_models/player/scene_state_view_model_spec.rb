require "rails_helper"

RSpec.describe Player::SceneStateViewModel, type: :view_model do
  let(:campaign) { create(:campaign) }
  let!(:aragorn) { create(:player_character, campaign:, name: "Aragorn", role: "pc") }
  let!(:caine)   { create(:player_character, campaign:, name: "Caine",   role: "companion") }
  before         { campaign.update!(main_character: aragorn) }
  let(:scene)    { create(:scene, campaign:) }

  describe "#phase" do
    it "is :framing when no events exist" do
      expect(described_class.new(scene).phase).to eq(:framing)
    end

    it "is :collecting when a declaration exists but PCs still undeclared" do
      # An empty party would skip collecting entirely; ensure there ARE PCs
      create(:player_character, campaign:, name: "Patric", role: "pc")
      create(:event, scene:, kind: "pc_declaration", pc: aragorn, turn_number: 1)
      expect(described_class.new(scene).phase).to eq(:collecting)
    end

    it "is :collecting when all PCs declared but companion check not yet offered" do
      create(:event, scene:, kind: "pc_declaration", pc: aragorn, turn_number: 1)
      expect(described_class.new(scene).phase).to eq(:collecting)
    end

    it "is :resolving when all PCs declared and companion check offered (or no companions)" do
      campaign.player_characters.companions.destroy_all
      create(:event, scene:, kind: "pc_declaration", pc: aragorn, turn_number: 1)
      # No companions exist — companion_prompt_offered? is vacuously true
      # Phase is :resolving only when a resolution job is in flight; otherwise treat as ready-to-resolve
      # For this VM, expose :ready_to_resolve as a sub-state of collecting that the controller acts on
      expect(described_class.new(scene)).to be_ready_to_resolve
    end

    it "is :awaiting_roll when most recent narration ends with an open chip" do
      create(:event, scene:, kind: "pc_declaration", pc: aragorn, turn_number: 1)
      create(:event, scene:, kind: "narration", turn_number: 1,
             payload: { "text" => "You see... [[1d20+3 — Aragorn Perception]]" })
      expect(described_class.new(scene).phase).to eq(:awaiting_roll)
    end

    it "is :idle when most recent narration ends at a handoff (?)" do
      create(:event, scene:, kind: "pc_declaration", pc: aragorn, turn_number: 1)
      create(:event, scene:, kind: "narration", turn_number: 1,
             payload: { "text" => "The door opens. What does Aragorn do?" })
      expect(described_class.new(scene).phase).to eq(:idle)
    end
  end

  describe "#undeclared_pcs_this_turn" do
    it "lists PCs without a declaration since last clean narration" do
      patric = create(:player_character, campaign:, name: "Patric", role: "pc")
      create(:event, scene:, kind: "pc_declaration", pc: aragorn, turn_number: 1)
      vm = described_class.new(scene)
      expect(vm.undeclared_pcs_this_turn.map(&:name)).to contain_exactly("Patric")
    end

    it "is empty after a clean narration" do
      create(:event, scene:, kind: "pc_declaration", pc: aragorn, turn_number: 1)
      create(:event, scene:, kind: "narration", turn_number: 1,
             payload: { "text" => "What do you do?" })
      expect(described_class.new(scene).undeclared_pcs_this_turn).to be_empty
    end
  end

  describe "#companion_prompt_offered?" do
    it "is vacuously true when no companions exist" do
      campaign.player_characters.companions.destroy_all
      expect(described_class.new(scene).companion_prompt_offered?).to eq(true)
    end

    it "is false when companions exist but no companion prompt this turn" do
      create(:event, scene:, kind: "pc_declaration", pc: aragorn, turn_number: 1)
      expect(described_class.new(scene).companion_prompt_offered?).to eq(false)
    end

    it "is true after a gm_collection_prompt with the companion-check label this turn" do
      create(:event, scene:, kind: "pc_declaration", pc: aragorn, turn_number: 1)
      create(:event, scene:, kind: "gm_collection_prompt", turn_number: 1,
             payload: { "text" => "Anything for Caine, or shall I run them?", "kind" => "companion_check" })
      expect(described_class.new(scene).companion_prompt_offered?).to eq(true)
    end
  end

  describe "#current_turn_number" do
    it "is 1 in framing phase" do
      expect(described_class.new(scene).current_turn_number).to eq(1)
    end

    it "tracks turn number from events" do
      create(:event, scene:, kind: "pc_declaration", pc: aragorn, turn_number: 1)
      create(:event, scene:, kind: "narration",                   turn_number: 1, payload: { "text" => "What now?" })
      create(:event, scene:, kind: "pc_declaration", pc: aragorn, turn_number: 2)
      expect(described_class.new(scene).current_turn_number).to eq(2)
    end
  end

  describe "asymmetry" do
    before do
      faction = create(:faction, campaign:)
      create(:faction_secret, faction:, label: "Hidden", content: "secret content X")
      npc = create(:npc, campaign:)
      create(:npc_secret, npc:, label: "Knows", content: "secret content Y")
    end

    it "does not leak secrets via any of its derived state" do
      vm = described_class.new(scene)
      # All the VM's exposed methods serialize to strings/symbols/IDs/AR instances —
      # none should ever surface the content of related *_secrets rows.
      surface = [
        vm.phase.to_s,
        vm.current_turn_number.to_s,
        vm.declared_this_turn.map(&:name).join(" "),
        vm.undeclared_pcs_this_turn.map(&:name).join(" "),
        vm.undeclared_companions_this_turn.map(&:name).join(" "),
        vm.companion_prompt_offered?.to_s
      ].join(" ")

      expect(surface).not_to leak_secrets_of(*Faction.all, *Npc.all)
    end
  end
end
