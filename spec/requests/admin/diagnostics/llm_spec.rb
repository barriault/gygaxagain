require "rails_helper"

RSpec.describe "Admin::Diagnostics::Llm", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  let(:successful_response_body) do
    {
      id: "msg_01TESTREQUESTID",
      type: "message",
      role: "assistant",
      model: "claude-sonnet-4-6",
      content: [ { type: "text", text: "Hi from the model." } ],
      stop_reason: "end_turn",
      usage: { input_tokens: 12, output_tokens: 5,
               cache_creation_input_tokens: 0, cache_read_input_tokens: 0 }
    }
  end

  before do
    host! "admin.gygaxagain.com"
    ENV["ANTHROPIC_API_KEY"] = "sk-ant-test-key"
  end

  describe "GET /diagnostics/llm" do
    context "unauthenticated" do
      it "redirects to sign-in" do
        get "/diagnostics/llm"
        expect(response).to have_http_status(:found)
      end
    end

    context "authenticated" do
      before { sign_in user }

      it "renders the form with no result panel" do
        get "/diagnostics/llm"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("LLM diagnostics")
        expect(response.body).not_to include("data-llm-call-id")
      end

      it "renders the form + result panel when ?call_id is the user's own call" do
        call = create(:llm_call, user: user)
        get "/diagnostics/llm", params: { call_id: call.id }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("data-llm-call-id=\"#{call.id}\"")
      end

      it "renders form only when ?call_id is another user's call" do
        call = create(:llm_call, user: other_user)
        get "/diagnostics/llm", params: { call_id: call.id }
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("data-llm-call-id=\"#{call.id}\"")
      end

      it "renders form only when ?call_id refers to a non-existent call" do
        get "/diagnostics/llm", params: { call_id: 999_999 }
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("data-llm-call-id")
      end
    end
  end

  describe "POST /diagnostics/llm" do
    context "unauthenticated" do
      it "redirects to sign-in" do
        post "/diagnostics/llm", params: { llm_diagnostics_form: { prompt: "Hi", model: "claude-sonnet-4-6" } }
        expect(response).to have_http_status(:found)
      end
    end

    context "authenticated, valid form, successful API call" do
      before do
        sign_in user
        stub_request(:post, "https://api.anthropic.com/v1/messages")
          .to_return(status: 200, body: successful_response_body.to_json,
                     headers: { "Content-Type" => "application/json" })
      end

      it "persists an LlmCall row" do
        expect {
          post "/diagnostics/llm",
               params: { llm_diagnostics_form: { prompt: "Hi", model: "claude-sonnet-4-6" } }
        }.to change(LlmCall, :count).by(1)
      end

      it "associates the row with current_user and no campaign" do
        post "/diagnostics/llm",
             params: { llm_diagnostics_form: { prompt: "Hi", model: "claude-sonnet-4-6" } }
        call = LlmCall.last
        expect(call.user).to eq(user)
        expect(call.campaign).to be_nil
        expect(call.purpose).to eq("diagnostics")
      end

      it "redirects to ?call_id=N" do
        post "/diagnostics/llm",
             params: { llm_diagnostics_form: { prompt: "Hi", model: "claude-sonnet-4-6" } }
        call = LlmCall.last
        expect(response).to redirect_to(admin_diagnostics_llm_path(call_id: call.id))
      end

      it "passes a non-blank system prompt to the API" do
        post "/diagnostics/llm",
             params: { llm_diagnostics_form: {
               prompt: "Hi", system_prompt: "You are a bard.", model: "claude-sonnet-4-6"
             } }
        expect(WebMock).to have_requested(:post, "https://api.anthropic.com/v1/messages")
          .with { |req| JSON.parse(req.body)["system"] == "You are a bard." }
      end

      it "omits system from the API request when blank" do
        post "/diagnostics/llm",
             params: { llm_diagnostics_form: {
               prompt: "Hi", system_prompt: "", model: "claude-sonnet-4-6"
             } }
        expect(WebMock).to have_requested(:post, "https://api.anthropic.com/v1/messages")
          .with { |req| !JSON.parse(req.body).key?("system") }
      end
    end

    context "authenticated, invalid form" do
      before { sign_in user }

      it "returns 422 with form errors" do
        post "/diagnostics/llm",
             params: { llm_diagnostics_form: { prompt: "", model: "claude-sonnet-4-6" } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("can&#39;t be blank").or include("can't be blank")
      end

      it "does not persist a row" do
        expect {
          post "/diagnostics/llm",
               params: { llm_diagnostics_form: { prompt: "", model: "claude-sonnet-4-6" } }
        }.not_to change(LlmCall, :count)
      end
    end

    context "authenticated, API returns 500" do
      before do
        sign_in user
        stub_request(:post, "https://api.anthropic.com/v1/messages")
          .to_return(status: 500, body: { error: { message: "boom" } }.to_json)
      end

      it "still persists an LlmCall row with error info" do
        expect {
          post "/diagnostics/llm",
               params: { llm_diagnostics_form: { prompt: "Hi", model: "claude-sonnet-4-6" } }
        }.to change(LlmCall, :count).by(1)

        call = LlmCall.last
        expect(call.total_cost_cents).to eq(0)
        expect(call.input_tokens).to eq(0)
        expect(call).not_to be_successful
      end

      it "redirects to ?call_id=N (so the user can see the error)" do
        post "/diagnostics/llm",
             params: { llm_diagnostics_form: { prompt: "Hi", model: "claude-sonnet-4-6" } }
        call = LlmCall.last
        expect(response).to redirect_to(admin_diagnostics_llm_path(call_id: call.id))
      end
    end

    context "authenticated, ANTHROPIC_API_KEY unset" do
      before do
        sign_in user
        ENV.delete("ANTHROPIC_API_KEY")
      end

      it "returns 503 with a flash alert" do
        post "/diagnostics/llm",
             params: { llm_diagnostics_form: { prompt: "Hi", model: "claude-sonnet-4-6" } }
        expect(response).to have_http_status(:service_unavailable)
        expect(response.body).to match(/LLM configuration error/i)
      end

      it "does not persist a row" do
        expect {
          post "/diagnostics/llm",
               params: { llm_diagnostics_form: { prompt: "Hi", model: "claude-sonnet-4-6" } }
        }.not_to change(LlmCall, :count)
      end
    end
  end
end
