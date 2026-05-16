# == Schema Information
#
# Table name: events
#
#  id          :bigint           not null, primary key
#  kind        :string           not null
#  occurred_at :datetime         not null
#  payload     :jsonb            not null
#  turn_number :integer
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  pc_id       :bigint
#  scene_id    :bigint           not null
#
# Indexes
#
#  index_events_on_kind                      (kind)
#  index_events_on_pc_id                     (pc_id)
#  index_events_on_scene_id                  (scene_id)
#  index_events_on_scene_id_and_occurred_at  (scene_id,occurred_at)
#  index_events_on_scene_id_and_turn_number  (scene_id,turn_number)
#
# Foreign Keys
#
#  fk_rails_...  (pc_id => player_characters.id) ON DELETE => nullify
#  fk_rails_...  (scene_id => scenes.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe Event, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:scene) }
  end

  describe ".kinds" do
    it "lists the Phase 9.1 event kinds" do
      expect(described_class.kinds.keys).to match_array(
        %w[narration pc_declaration gm_collection_prompt dice_roll scene_transition]
      )
    end

    it "does not include the retired Phase 8 kinds" do
      expect(described_class.kinds.keys).not_to include("player_action", "oracle_query")
    end
  end

  describe "kind enum" do
    %w[narration dice_roll scene_transition].each do |kind|
      it "round-trips kind=#{kind}" do
        event = create(:event, kind: kind)
        expect(event.reload.kind).to eq(kind)
      end
    end

    it "round-trips kind=pc_declaration" do
      event = create(:event, kind: "pc_declaration", payload: { text: "I declare!" })
      expect(event.reload.kind).to eq("pc_declaration")
    end

    it "round-trips kind=gm_collection_prompt" do
      event = create(:event, kind: "gm_collection_prompt", payload: { prompt: "What next?" })
      expect(event.reload.kind).to eq("gm_collection_prompt")
    end

    it "raises ArgumentError on an unknown kind" do
      expect { build(:event, kind: "unknown_kind") }.to raise_error(ArgumentError)
    end
  end

  describe "occurred_at default" do
    it "defaults to Time.current on create when not provided" do
      freeze_time = Time.parse("2026-05-14 12:00:00 UTC")
      event = travel_to(freeze_time) { create(:event, occurred_at: nil) }
      expect(event.occurred_at).to be_within(1.second).of(freeze_time)
    end

    it "honors an explicit occurred_at" do
      t = 1.day.ago
      event = create(:event, occurred_at: t)
      expect(event.occurred_at).to be_within(1.second).of(t)
    end
  end

  describe "payload" do
    it "stores arbitrary jsonb" do
      event = create(:event, kind: "dice_roll", payload: { expression: "1d20" })
      expect(event.reload.payload).to eq("expression" => "1d20")
    end

    it "defaults to empty hash if not provided" do
      event = create(:event, payload: {})
      expect(event.reload.payload).to eq({})
    end
  end

  describe "cascade on scene delete" do
    it "removes events when their scene is deleted at the DB level" do
      scene = create(:scene)
      event = create(:event, scene: scene)
      ActiveRecord::Base.connection.execute("DELETE FROM scenes WHERE id = #{scene.id}")
      expect(Event.where(id: event.id)).to be_empty
    end
  end

  describe "trait factories" do
    it "creates a dice_roll event via trait" do
      event = create(:event, :dice_roll)
      expect(event.kind).to eq("dice_roll")
      expect(event.payload).to include("expression")
    end
  end

  describe "pc association" do
    it "optionally belongs to a player_character via pc_id" do
      assoc = described_class.reflect_on_association(:pc)
      expect(assoc.options[:optional]).to eq(true)
      expect(assoc.options[:class_name]).to eq("PlayerCharacter")
    end
  end

  describe "turn_number" do
    it "is nullable and accepts integers" do
      event = create(:event, turn_number: 7)
      expect(event.reload.turn_number).to eq(7)
    end
  end
end
