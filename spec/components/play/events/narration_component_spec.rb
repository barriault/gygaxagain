require "rails_helper"

RSpec.describe Play::Events::NarrationComponent, type: :component do
  let(:campaign) { create(:campaign) }
  let(:scene)    { create(:scene, campaign: campaign) }
  let(:event) do
    create(:event,
           scene: scene,
           kind: "narration",
           payload: { "text" => "The tavern is quiet. Rain drips from the eaves." },
           occurred_at: 5.minutes.ago)
  end

  it "renders the narration text" do
    render_inline(described_class.new(event: event))

    expect(page).to have_text("The tavern is quiet. Rain drips from the eaves.")
  end

  it "renders a relative timestamp" do
    render_inline(described_class.new(event: event))

    expect(page).to have_text(/ago/)
  end

  describe "status branches" do
    it "renders a streaming cursor when status is streaming" do
      event = create(:event, scene: scene, kind: "narration",
                     payload: { "text" => "Halfway through", "status" => "streaming" })
      rendered = render_inline(described_class.new(event: event))
      expect(rendered.text).to include("Halfway through")
      expect(rendered.css("[data-narration-status='streaming']")).to be_present
    end

    it "renders the final text when status is complete" do
      event = create(:event, scene: scene, kind: "narration",
                     payload: { "text" => "All done.", "status" => "complete" })
      rendered = render_inline(described_class.new(event: event))
      expect(rendered.text).to include("All done.")
      expect(rendered.css("[data-narration-status='streaming']")).to be_empty
    end

    it "renders an error state when status is errored" do
      event = create(:event, scene: scene, kind: "narration",
                     payload: { "text" => "Partial",
                                "status" => "errored",
                                "error_message" => "boom" })
      rendered = render_inline(described_class.new(event: event))
      expect(rendered.text).to include("Partial")
      expect(rendered.text).to include("the narrator couldn't finish")
      expect(rendered.css(".border-rose-700, .border-rose-600")).not_to be_empty
    end
  end

  describe "markdown rendering" do
    it "renders **bold** as <strong>" do
      event = create(:event, kind: "narration", payload: { "text" => "He **slams** the door.", "status" => "complete" })
      rendered = render_inline(described_class.new(event: event))
      expect(rendered.to_s).to include("<strong>slams</strong>")
    end
  end

  describe "dice chips" do
    it "renders [[…]] as a clickable button" do
      event = create(:event, kind: "narration", payload: { "text" => "Roll [[1d20+3 — Aragorn Strength]] now.", "status" => "complete" })
      rendered = render_inline(described_class.new(event: event))
      expect(rendered.to_s).to include('class="dice-chip"')
      expect(rendered.to_s).to include("1d20+3")
    end
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
