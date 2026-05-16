class NarrationJob < ApplicationJob
  queue_as :narration

  discard_on ActiveRecord::RecordNotFound, KeyError, Llm::ConfigError

  FLUSH_MS    = 80
  FLUSH_BYTES = 25

  def perform(scene_id:, narration_event_id:, trigger:)
    scene    = Scene.find(scene_id)
    event    = scene.events.find(narration_event_id)
    campaign = scene.campaign
    user     = campaign.user

    prompt = build_prompt(scene:, trigger:)

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
        flush(event, accumulator, status: "streaming")
        buffer.clear
        last_flush = now
      end
    end

    if llm_call.successful?
      finalize_success(event, accumulator, llm_call)
    else
      finalize_error(event, accumulator, llm_call)
    end
  rescue StandardError => e
    # Mark the event errored so the user sees a clear "failed" state instead
    # of perma-streaming. Re-raise so ActiveJob can still apply retry/discard.
    if defined?(event) && event
      error_message = "#{e.class.name}: #{e.message}".byteslice(0, 500)
      text          = defined?(accumulator) ? accumulator.to_s : ""
      event.with_lock do
        event.update!(payload: event.payload.merge(
          "text" => text, "status" => "errored", "error_message" => error_message
        ))
      end
      broadcast_replace(event)
    end
    Rails.logger.error("[NarrationJob] #{e.class}: #{e.message}\n#{e.backtrace.first(10).join("\n")}")
    raise
  end

  private

  def build_prompt(scene:, trigger:)
    case trigger.to_s
    when "framing"
      Narrator::PromptBuilder.framing(scene: scene)
    when "resolution"
      decls = scene.events
                   .where(kind: "pc_declaration",
                          turn_number: Player::SceneStateViewModel.new(scene).current_turn_number)
                   .order(:occurred_at, :id)
                   .map { |e| { pc: e.pc, text: e.payload["text"] } }
      Narrator::PromptBuilder.resolution(scene: scene, current_turn_declarations: decls)
    when "continuation"
      latest_roll = scene.events.where(kind: "dice_roll").order(:occurred_at, :id).last
      Narrator::PromptBuilder.continuation(scene: scene, latest_roll: latest_roll)
    else
      raise KeyError, "Unknown trigger: #{trigger}"
    end
  end

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
