module Admin
  module Diagnostics
    class LlmController < Admin::ApplicationController
      def show
        form = ::Llm::DiagnosticsForm.new(model: default_model)
        last_call = load_last_call(params[:call_id])
        render Admin::Diagnostics::Llm::ShowComponent.new(form: form, last_call: last_call)
      end

      def create
        form = ::Llm::DiagnosticsForm.new(form_params)

        unless form.valid?
          render Admin::Diagnostics::Llm::ShowComponent.new(form: form, last_call: nil),
                 status: :unprocessable_entity
          return
        end

        begin
          call = ::Llm::Call.execute(
            purpose:  :diagnostics,
            system:   form.system_prompt.presence,
            messages: [ { role: "user", content: form.prompt } ],
            model:    form.model,
            user:     current_user
          )
          redirect_to admin_diagnostics_llm_path(call_id: call.id)
        rescue ::Llm::ConfigError => e
          flash.now[:alert] = "LLM configuration error: #{e.message}"
          render Admin::Diagnostics::Llm::ShowComponent.new(form: form, last_call: nil),
                 status: :service_unavailable
        end
      end

      private

      def form_params
        params.require(:llm_diagnostics_form).permit(:prompt, :system_prompt, :model)
      end

      def default_model
        ::Llm::Provider::PURPOSES.fetch(:diagnostics)[:model]
      end

      def load_last_call(id)
        return nil if id.blank?
        current_user.llm_calls.find_by(id: id)
      end
    end
  end
end
