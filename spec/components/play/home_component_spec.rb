require "rails_helper"

RSpec.describe Play::HomeComponent, type: :component do
  # Asymmetry-exempt: static landing, no ViewModel input.
  # See EXEMPT_COMPONENTS in spec/asymmetry/coverage_spec.rb.

  it "renders the project name, tagline, and private-alpha tag" do
    render_inline(described_class.new)
    expect(page).to have_text("gygaxagain")
    expect(page).to have_text(/solo D&D/i)
    expect(page).to have_text(/private alpha/i)
  end
end
