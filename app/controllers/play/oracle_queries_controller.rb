module Play
  class OracleQueriesController < ::ApplicationController
    before_action :load_scene

    def create
      attrs = params.require(:oracle_query).permit(:question, :likelihood)
      question = attrs.fetch(:question, "").to_s.strip
      likelihood = attrs.fetch(:likelihood, ::Play::Oracle::FormComponent::DEFAULT_LIKELIHOOD).to_s
      likelihood = ::Play::Oracle::FormComponent::DEFAULT_LIKELIHOOD if likelihood.blank?
      likelihood = ::Play::Oracle::FormComponent::DEFAULT_LIKELIHOOD unless ::Mythic::FateChart::LIKELIHOODS.include?(likelihood)

      if question.blank?
        return respond_with_error(
          question: question,
          likelihood: likelihood,
          message: "enter a question"
        )
      end

      result = ::Mythic::Oracle.call(
        question: question,
        likelihood: likelihood,
        chaos_factor: @scene.campaign.chaos_factor
      )

      event = @scene.events.create!(
        kind: "oracle_query",
        occurred_at: Time.current,
        payload: {
          "question"               => result.question,
          "answer"                 => result.outcome.to_s.humanize,
          "outcome"                => result.outcome.to_s,
          "likelihood"             => result.likelihood,
          "chaos"                  => result.chaos_factor,
          "roll"                   => result.roll,
          "random_event_triggered" => result.random_event_triggered
        }
      )

      respond_to do |f|
        f.turbo_stream { render turbo_stream: stream_success(event) }
        f.html { redirect_to play_campaign_scene_path(@scene.campaign, @scene) }
      end
    end

    private

    def load_scene
      @scene = current_user
                 .campaigns
                 .find(params[:campaign_id])
                 .scenes
                 .find(params[:scene_id])
    end

    def stream_success(event)
      [
        turbo_stream.append(
          helpers.dom_id(@scene, :log),
          Play::Events::Component.for(event).new(event: event)
        ),
        turbo_stream.remove(helpers.dom_id(@scene, :log_empty)),
        turbo_stream.replace(
          helpers.dom_id(@scene, :oracle_form),
          Play::Oracle::FormComponent.new(scene: @scene)
        )
      ]
    end

    def respond_with_error(question:, likelihood:, message:)
      respond_to do |f|
        f.turbo_stream do
          render turbo_stream: turbo_stream.replace(
                   helpers.dom_id(@scene, :oracle_form),
                   Play::Oracle::FormComponent.new(
                     scene: @scene, question: question, likelihood: likelihood, error: message
                   )
                 ),
                 status: :unprocessable_content
        end
        f.html do
          redirect_to play_campaign_scene_path(@scene.campaign, @scene),
                      alert: message
        end
      end
    end
  end
end
