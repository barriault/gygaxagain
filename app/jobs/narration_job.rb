class NarrationJob < ApplicationJob
  queue_as :narration

  FLUSH_MS    = 80
  FLUSH_BYTES = 25

  def perform(narration_event_id)
    narration_event = Event.find(narration_event_id)
    scene           = narration_event.scene
    campaign        = scene.campaign
    user            = campaign.user
    player_action   = Event.find(narration_event.payload.fetch("player_action_event_id"))

    prompt = Narrator::PromptBuilder.call(
      scene: scene,
      player_action_text: player_action.payload.fetch("text")
    )

    accumulator = +""
    buffer      = +""
    last_flush  = monotonic_ms

    llm_call = Llm::Call.execute_streaming(
      purpose: :narration,
      user: user, campaign: campaign, scene: scene,
      **prompt.to_call_kwargs
    ) do |text:|
      accumulator << text
      buffer      << text
      now = monotonic_ms
      if now - last_flush >= FLUSH_MS || buffer.bytesize >= FLUSH_BYTES
        flush(narration_event, accumulator, status: "streaming")
        buffer.clear
        last_flush = now
      end
    end

    if llm_call.successful?
      finalize_success(narration_event, accumulator, llm_call)
    else
      finalize_error(narration_event, accumulator, llm_call)
    end
  end

  private

  def flush(event, text, status:)
    event.with_lock do
      event.update!(payload: event.payload.merge("text" => text, "status" => status))
    end
    broadcast_replace(event)
  end

  def finalize_success(event, text, llm_call)
    event.with_lock do
      event.update!(payload: event.payload.merge(
        "text" => text, "status" => "complete", "llm_call_id" => llm_call.id
      ))
    end
    broadcast_replace(event)
  end

  def finalize_error(event, text, llm_call)
    event.with_lock do
      event.update!(payload: event.payload.merge(
        "text" => text, "status" => "errored",
        "llm_call_id" => llm_call.id,
        "error_message" => llm_call.error_message
      ))
    end
    broadcast_replace(event)
  end

  def broadcast_replace(event)
    scene = event.scene
    user  = scene.campaign.user

    Turbo::StreamsChannel.broadcast_replace_to(
      [ scene, user ],
      target:     ActionView::RecordIdentifier.dom_id(event),
      renderable: Play::Events::NarrationComponent.new(event: event),
      layout:     false
    )
  end

  def monotonic_ms
    (Process.clock_gettime(Process::CLOCK_MONOTONIC) * 1000).to_i
  end
end
