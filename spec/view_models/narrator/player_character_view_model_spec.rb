require "rails_helper"

RSpec.describe Narrator::PlayerCharacterViewModel, type: :view_model do
  let(:pc) { create(:player_character, name: "Aragorn", notes: "DM NOTE") }

  it "exposes name, role, class_name, level, pronouns, and notes" do
    vm = described_class.new(pc)
    expect(vm.to_h).to include(
      name: "Aragorn",
      role: "pc",
      class_name: pc.class_name,
      level: pc.level,
      pronouns: pc.pronouns,
      notes: "DM NOTE"
    )
  end
end
