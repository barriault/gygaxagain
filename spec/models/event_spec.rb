require "rails_helper"

RSpec.describe Event, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:scene) }
  end

  describe "kind enum" do
    %w[narration dice_roll oracle_query scene_transition].each do |kind|
      it "round-trips kind=#{kind}" do
        event = create(:event, kind: kind)
        expect(event.reload.kind).to eq(kind)
      end
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
end
