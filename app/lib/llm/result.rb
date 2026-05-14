module Llm
  Result = Data.define(
    :text,
    :input_tokens,
    :output_tokens,
    :cache_creation_tokens,
    :cache_read_tokens,
    :provider_request_id,
    :prompt_payload,
    :response_payload,
    :latency_ms,
    :error
  ) do
    def successful?
      error.nil?
    end
  end
end
