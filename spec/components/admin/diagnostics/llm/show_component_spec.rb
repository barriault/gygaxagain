require "rails_helper"

RSpec.describe Admin::Diagnostics::Llm::ShowComponent, type: :component do
  let(:form) { Llm::DiagnosticsForm.new(model: "claude-sonnet-4-6") }

  it "renders the form with prompt, system_prompt, and model fields" do
    render_inline(described_class.new(form: form, last_call: nil))

    expect(page).to have_field("llm_diagnostics_form[prompt]")
    expect(page).to have_field("llm_diagnostics_form[system_prompt]")
    expect(page).to have_select("llm_diagnostics_form[model]")
  end

  it "populates the model dropdown from Llm::Pricing.known_models" do
    render_inline(described_class.new(form: form, last_call: nil))
    Llm::Pricing.known_models.each do |model|
      expect(page).to have_css("option[value='#{model}']")
    end
  end

  it "renders no result panel when last_call is nil" do
    render_inline(described_class.new(form: form, last_call: nil))
    expect(page).not_to have_css("[data-llm-call-id]")
  end

  it "renders a result panel when last_call is provided" do
    call = create(:llm_call)
    render_inline(described_class.new(form: form, last_call: call))
    expect(page).to have_css("[data-llm-call-id='#{call.id}']")
  end

  it "renders form errors when the form is invalid" do
    invalid_form = Llm::DiagnosticsForm.new(prompt: "", model: "claude-sonnet-4-6")
    invalid_form.valid?
    render_inline(described_class.new(form: invalid_form, last_call: nil))
    expect(page).to have_content(/can't be blank/i)
  end
end
