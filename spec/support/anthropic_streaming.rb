# Helpers for stubbing Anthropic Messages streaming responses (server-sent events).
#
# Usage:
#   stub_anthropic_streaming(text_chunks: ["Hello ", "world."],
#                            input_tokens: 12, output_tokens: 7)
module AnthropicStreamingHelpers
  def stub_anthropic_streaming(text_chunks:, input_tokens: 10, output_tokens: 5,
                               cache_creation_tokens: 0, cache_read_tokens: 0,
                               stop_reason: "end_turn", stop_sequence: nil,
                               message_id: "msg_test_#{SecureRandom.hex(4)}")
    body = build_sse_body(
      text_chunks: text_chunks,
      message_id: message_id,
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      cache_creation_tokens: cache_creation_tokens,
      cache_read_tokens: cache_read_tokens,
      stop_reason: stop_reason,
      stop_sequence: stop_sequence
    )

    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(
        status: 200,
        headers: { "Content-Type" => "text/event-stream" },
        body: body
      )
  end

  def stub_anthropic_streaming_error(status:, error_class: "Anthropic::Errors::APIStatusError",
                                     message: "stub error")
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(
        status: status,
        headers: { "Content-Type" => "application/json" },
        body: { "error" => { "type" => "api_error", "message" => message } }.to_json
      )
  end

  private

  def build_sse_body(text_chunks:, message_id:, input_tokens:, output_tokens:,
                     cache_creation_tokens:, cache_read_tokens:,
                     stop_reason: "end_turn", stop_sequence: nil)
    events = []
    events << sse_event("message_start", {
      type: "message_start",
      message: {
        id: message_id, type: "message", role: "assistant", model: "claude-sonnet-4-6",
        content: [], stop_reason: nil, stop_sequence: nil,
        usage: {
          input_tokens: input_tokens, output_tokens: 0,
          cache_creation_input_tokens: cache_creation_tokens,
          cache_read_input_tokens: cache_read_tokens
        }
      }
    })
    events << sse_event("content_block_start", {
      type: "content_block_start", index: 0,
      content_block: { type: "text", text: "" }
    })
    text_chunks.each do |chunk|
      events << sse_event("content_block_delta", {
        type: "content_block_delta", index: 0,
        delta: { type: "text_delta", text: chunk }
      })
    end
    events << sse_event("content_block_stop", { type: "content_block_stop", index: 0 })
    events << sse_event("message_delta", {
      type: "message_delta",
      delta: { stop_reason: stop_reason, stop_sequence: stop_sequence },
      usage: { output_tokens: output_tokens }
    })
    events << sse_event("message_stop", { type: "message_stop" })
    events.join
  end

  def sse_event(name, data)
    "event: #{name}\ndata: #{data.to_json}\n\n"
  end
end

RSpec.configure do |c|
  c.include AnthropicStreamingHelpers
end
