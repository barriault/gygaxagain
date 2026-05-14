require "rails_helper"

RSpec.describe Play::Events::DiceRollComponent, type: :component do
  let(:campaign) { create(:campaign) }
  let(:scene)    { create(:scene, campaign: campaign) }
  let(:event) do
    create(:event, :dice_roll,
           scene: scene,
           payload: { "expression" => "2d6+3", "result" => 10, "breakdown" => [ 4, 3, "+3" ] },
           occurred_at: 2.minutes.ago)
  end

  it "renders the dice expression" do
    render_inline(described_class.new(event: event))

    expect(page).to have_text("2d6+3")
  end

  it "renders the result" do
    render_inline(described_class.new(event: event))

    expect(page).to have_text("10")
  end

  it "renders the breakdown when present" do
    render_inline(described_class.new(event: event))

    expect(page).to have_text(/4.*3.*\+3/)
  end

  it "omits the breakdown line when absent" do
    event_no_breakdown = create(:event,
                                scene: scene,
                                kind: "dice_roll",
                                payload: { "expression" => "1d20", "result" => 15 })
    render_inline(described_class.new(event: event_no_breakdown))

    expect(page).to have_text("1d20")
    expect(page).to have_text("15")
  end

  describe "asymmetry" do
    let(:faction) { create(:faction, campaign: campaign) }
    let(:npc)     { create(:npc, campaign: campaign) }

    before do
      create(:faction_secret, faction: faction, label: "hidden temple", content: "in the swamp")
      create(:npc_secret,     npc: npc,         label: "true identity", content: "is a doppelganger")
    end

    it "does not leak secrets of related records" do
      rendered = render_inline(described_class.new(event: event)).to_s
      expect(rendered).not_to leak_secrets_of(faction, npc)
    end
  end
end
