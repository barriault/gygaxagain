require "rails_helper"

RSpec.describe Admin::Diagnostics::Llm::ResultPanelComponent, type: :component do
  describe "successful call" do
    let(:call) { create(:llm_call) }

    it "renders the response text" do
      render_inline(described_class.new(call: call))
      expect(page).to have_content("Hi there!")
    end

    it "renders the model and tokens" do
      render_inline(described_class.new(call: call))
      expect(page).to have_content("claude-sonnet-4-6")
      expect(page).to have_content("100")  # input_tokens
      expect(page).to have_content("50")   # output_tokens
    end

    it "renders the cost in dollars" do
      render_inline(described_class.new(call: call))
      expect(page).to have_content("$1.05")
    end

    it "renders the provider_request_id" do
      render_inline(described_class.new(call: call))
      expect(page).to have_content(call.provider_request_id)
    end

    it "carries data-llm-call-id on its root element" do
      render_inline(described_class.new(call: call))
      expect(page).to have_css("[data-llm-call-id='#{call.id}']")
    end

    it "renders pretty-printed JSON for prompt and response payloads" do
      render_inline(described_class.new(call: call))
      expect(page).to have_css("details", count: 2)
      expect(page).to have_content("\"messages\"")
      expect(page).to have_content("\"content\"")
    end
  end

  describe "errored call" do
    let(:call) { create(:llm_call, :errored) }

    it "renders an error banner" do
      render_inline(described_class.new(call: call))
      expect(page).to have_content("Internal server error")
    end

    it "still carries data-llm-call-id" do
      render_inline(described_class.new(call: call))
      expect(page).to have_css("[data-llm-call-id='#{call.id}']")
    end
  end
end
