require "rails_helper"

RSpec.describe Admin::Campaigns::ChaosFactorComponent, type: :component do
  let(:user) { create(:user) }

  it "renders the current chaos factor" do
    campaign = create(:campaign, user: user, chaos_factor: 5)
    render_inline(described_class.new(campaign: campaign))

    expect(page).to have_text(/chaos factor/i)
    expect(page).to have_text("5")
  end

  it "renders − and + buttons" do
    campaign = create(:campaign, user: user, chaos_factor: 5)
    render_inline(described_class.new(campaign: campaign))

    expect(page).to have_button("−")
    expect(page).to have_button("+")
  end

  it "disables the − button at the floor" do
    campaign = create(:campaign, user: user, chaos_factor: 1)
    render_inline(described_class.new(campaign: campaign))

    expect(page).to have_button("−", disabled: true)
    expect(page).to have_button("+", disabled: false)
  end

  it "disables the + button at the ceiling" do
    campaign = create(:campaign, user: user, chaos_factor: 9)
    render_inline(described_class.new(campaign: campaign))

    expect(page).to have_button("−", disabled: false)
    expect(page).to have_button("+", disabled: true)
  end
end
