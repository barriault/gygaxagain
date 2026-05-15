class SceneAuditJob < ApplicationJob
  queue_as :default

  def perform(scene_id)
    scene = Scene.find(scene_id)
    return if scene.audit.present?

    prompt = Narrator::AuditPromptBuilder.call(scene: scene)

    llm_call = Llm::Call.execute(
      purpose: :bookkeeper_audit,
      user: scene.campaign.user, campaign: scene.campaign, scene: scene,
      max_tokens: 2048,
      **prompt.to_call_kwargs
    )

    parsed = parse_audit_result(llm_call)

    SceneAudit.create!(
      scene: scene,
      llm_call: llm_call,
      verdict: parsed.fetch(:verdict),
      result: parsed.fetch(:result)
    )
  end

  private

  def parse_audit_result(llm_call)
    return failed(llm_call, "call_failed") unless llm_call.successful?

    raw = llm_call.text.to_s
    json = extract_json(raw)
    parsed = JSON.parse(json)

    verdict = parsed.fetch("verdict")
    raise KeyError unless %w[pass concerns fail].include?(verdict)

    { verdict: verdict, result: parsed }
  rescue JSON::ParserError, KeyError
    failed(llm_call, "audit_parse_failed", raw: llm_call.text)
  end

  def failed(llm_call, error_kind, raw: nil)
    {
      verdict: "fail",
      result: {
        "error" => error_kind,
        "raw"   => raw,
        "llm_call_error" => llm_call.error_message
      }.compact
    }
  end

  def extract_json(text)
    # Models occasionally wrap JSON in ```json fences. Strip non-brace prefix/suffix.
    body = text.to_s.strip
    body = body.sub(/\A.*?(\{)/m, '\1')
    body = body.sub(/\A(.*\}).*?\z/m, '\1')
    body
  end
end
