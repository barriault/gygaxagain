require "rails_helper"

RSpec.describe Admin::NavComponent, type: :component do
  it "renders a Campaigns link" do
    render_inline(described_class.new(current_path: "/dashboard"))
    expect(page).to have_link("Campaigns", href: "/campaigns")
  end

  it "renders a Diagnostics link" do
    render_inline(described_class.new(current_path: "/dashboard"))
    expect(page).to have_link("Diagnostics → LLM", href: "/diagnostics/llm")
  end

  it "marks the Campaigns link as active when path matches" do
    render_inline(described_class.new(current_path: "/campaigns"))
    expect(page).to have_css("a[href='/campaigns'][aria-current='page']")
  end

  it "marks the Diagnostics link as active when path starts with /diagnostics" do
    render_inline(described_class.new(current_path: "/diagnostics/llm"))
    expect(page).to have_css("a[href='/diagnostics/llm'][aria-current='page']")
  end
end
