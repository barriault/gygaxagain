require "rails_helper"

RSpec.describe Play::Events::OracleQueryComponent, type: :component do
  let(:campaign) { create(:campaign) }
  let(:scene)    { create(:scene, campaign: campaign) }
  let(:event) do
    create(:event, :oracle_query,
           scene: scene,
           payload: {
             "question"   => "Is it raining?",
             "likelihood" => "even_odds",
             "chaos"      => 5,
             "answer"     => "yes"
           },
           occurred_at: 1.minute.ago)
  end

  it "renders the question" do
    render_inline(described_class.new(event: event))

    expect(page).to have_text("Is it raining?")
  end

  it "renders the answer" do
    render_inline(described_class.new(event: event))

    expect(page).to have_text("yes")
  end

  it "renders the likelihood and chaos labels" do
    render_inline(described_class.new(event: event))

    expect(page).to have_text(/even.odds/i)
    expect(page).to have_text(/chaos.*5/i)
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
