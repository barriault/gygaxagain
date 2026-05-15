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

  it "renders the seven die chips" do
    render_inline(described_class.new(scene: scene))

    %w[d4 d6 d8 d10 d12 d20 d100].each do |die|
      expect(page).to have_button(die)
    end
  end

  it "renders the five modifier chips" do
    render_inline(described_class.new(scene: scene))

    [ "+", "−", "adv", "dis", "clear" ].each do |label|
      expect(page).to have_button(label)
    end
  end

  it "wires die chips to the pickDie Stimulus action with a die param" do
    render_inline(described_class.new(scene: scene))

    chip = page.find_button("d6")
    expect(chip["data-action"]).to include("click->dice-form#pickDie")
    expect(chip["data-dice-form-die-param"]).to eq("d6")
    expect(chip["data-dice-form-target"]).to include("dieChip")
  end

  it "wires the + and − chips to bumpModifier with a delta param" do
    render_inline(described_class.new(scene: scene))

    plus = page.find_button("+")
    expect(plus["data-action"]).to include("click->dice-form#bumpModifier")
    expect(plus["data-dice-form-delta-param"]).to eq("1")

    minus = page.find_button("−")
    expect(minus["data-action"]).to include("click->dice-form#bumpModifier")
    expect(minus["data-dice-form-delta-param"]).to eq("-1")
  end

  it "wires the adv and dis chips to setMode with a mode param" do
    render_inline(described_class.new(scene: scene))

    adv = page.find_button("adv")
    expect(adv["data-action"]).to include("click->dice-form#setMode")
    expect(adv["data-dice-form-mode-param"]).to eq("adv")

    dis = page.find_button("dis")
    expect(dis["data-action"]).to include("click->dice-form#setMode")
    expect(dis["data-dice-form-mode-param"]).to eq("dis")
  end

  it "wires the clear chip to clearAll" do
    render_inline(described_class.new(scene: scene))

    clear = page.find_button("clear")
    expect(clear["data-action"]).to include("click->dice-form#clearAll")
  end

  it "wires the expression field to dice-form#expressionInput for detach detection" do
    render_inline(described_class.new(scene: scene))

    field = page.find_field("dice_roll[expression]")
    expect(field["data-action"]).to include("input->dice-form#expressionInput")
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
