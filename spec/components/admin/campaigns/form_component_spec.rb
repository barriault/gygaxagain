require "rails_helper"

RSpec.describe Admin::Campaigns::FormComponent, type: :component do
  let(:user) { create(:user) }
  let(:new_campaign) { user.campaigns.build }

  it "renders name and description fields" do
    render_inline(described_class.new(
      campaign: new_campaign,
      form_url: "/campaigns",
      method: :post
    ))
    expect(page).to have_field("Name")
    expect(page).to have_field("Description")
  end

  it "renders a submit button" do
    render_inline(described_class.new(
      campaign: new_campaign,
      form_url: "/campaigns",
      method: :post
    ))
    expect(page).to have_button("Create campaign")
  end

  it "renders an error summary when the campaign has errors" do
    invalid = user.campaigns.build(name: "")
    invalid.valid?

    render_inline(described_class.new(
      campaign: invalid,
      form_url: "/campaigns",
      method: :post
    ))
    expect(page).to have_text(/prohibited this campaign|errors prevented/i)
  end
end
