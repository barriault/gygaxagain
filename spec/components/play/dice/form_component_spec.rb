require "rails_helper"

RSpec.describe Play::Dice::FormComponent, type: :component do
  include Rails.application.routes.url_helpers

  let(:user) { create(:user) }
  let(:campaign) { create(:campaign, user: user) }
  let(:scene)    { create(:scene, campaign: campaign) }

  it "renders an expression input and a Roll button" do
    render_inline(described_class.new(scene: scene))

    expect(page).to have_field("dice_roll[expression]")
    expect(page).to have_button("Roll")
  end

  it "posts to the dice_rolls#create route" do
    render_inline(described_class.new(scene: scene))

    expected_path = campaign_scene_dice_rolls_path(campaign, scene)
    expect(page.find("form")["action"]).to eq(expected_path)
  end

  it "renders the four quick-roll chips" do
    render_inline(described_class.new(scene: scene))

    %w[d20 d100 2d6 4d6kh3].each do |chip|
      expect(page).to have_button(chip)
    end
  end

  it "echoes a sticky expression on error" do
    render_inline(described_class.new(scene: scene, expression: "1d6+wat"))

    expect(page.find_field("dice_roll[expression]").value).to eq("1d6+wat")
  end

  it "renders the inline error when provided" do
    render_inline(described_class.new(scene: scene, error: "unparseable at position 3"))

    expect(page).to have_text(/unparseable/)
  end

  it "includes the dice-form Stimulus controller hook" do
    render_inline(described_class.new(scene: scene))

    expect(page).to have_css("form[data-controller~='dice-form']")
  end

  it "carries the scene's dom_id on its container element" do
    render_inline(described_class.new(scene: scene))

    expect(page).to have_css("##{ApplicationController.helpers.dom_id(scene, :dice_form)}")
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
