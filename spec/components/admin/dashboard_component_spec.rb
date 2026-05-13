require "rails_helper"

RSpec.describe Admin::DashboardComponent, type: :component do
  it "renders an admin-dashboard placeholder" do
    render_inline(described_class.new)
    expect(page).to have_text(/admin dashboard/i)
  end
end
