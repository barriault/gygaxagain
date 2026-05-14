require "rails_helper"

RSpec.describe Play::Oracle::FormComponent, type: :component do
  include Rails.application.routes.url_helpers

  let(:user) { create(:user) }
  let(:campaign) { create(:campaign, user: user, chaos_factor: 4) }
  let(:scene)    { create(:scene, campaign: campaign) }

  it "renders a question input and an Ask button" do
    render_inline(described_class.new(scene: scene))

    expect(page).to have_field("oracle_query[question]")
    expect(page).to have_button("Ask")
  end

  it "posts to the oracle_queries#create route" do
    render_inline(described_class.new(scene: scene))

    expected_path = campaign_scene_oracle_queries_path(campaign, scene)
    expect(page.find("form")["action"]).to eq(expected_path)
  end

  it "renders a likelihood select with the 9 Mythic 2e values, defaulting to 50_50" do
    render_inline(described_class.new(scene: scene))

    %w[impossible nearly_impossible very_unlikely unlikely 50_50 likely very_likely nearly_certain certain].each do |val|
      expect(page).to have_css("select option[value='#{val}']")
    end
    expect(page.find_field("oracle_query[likelihood]").value).to eq("50_50")
  end

  it "renders the campaign's chaos factor" do
    render_inline(described_class.new(scene: scene))

    expect(page).to have_text(/chaos 4/i)
  end

  it "echoes a sticky question on error" do
    render_inline(described_class.new(scene: scene, question: "Does it open?"))

    expect(page.find_field("oracle_query[question]").value).to eq("Does it open?")
  end

  it "echoes a sticky likelihood on error" do
    render_inline(described_class.new(scene: scene, likelihood: "very_likely"))

    expect(page.find_field("oracle_query[likelihood]").value).to eq("very_likely")
  end

  it "renders the inline error when provided" do
    render_inline(described_class.new(scene: scene, error: "enter a question"))

    expect(page).to have_text("enter a question")
  end

  it "includes the oracle-form Stimulus controller hook" do
    render_inline(described_class.new(scene: scene))

    expect(page).to have_css("form[data-controller~='oracle-form']")
  end

  it "carries the scene's dom_id on its container element" do
    render_inline(described_class.new(scene: scene))

    expect(page).to have_css("##{ApplicationController.helpers.dom_id(scene, :oracle_form)}")
  end

  describe "asymmetry" do
    let(:faction) { create(:faction, campaign: campaign) }
    let(:npc)     { create(:npc, campaign: campaign) }

    before do
      create(:faction_secret, faction: faction, label: "hidden temple", content: "in the swamp")
      create(:npc_secret,     npc: npc,         label: "true identity", content: "is a doppelganger")
    end

    it "does not leak secrets of related records" do
      rendered = render_inline(described_class.new(scene: scene)).to_s
      expect(rendered).not_to leak_secrets_of(faction, npc)
    end
  end
end
