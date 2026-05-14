module Narrator
  Prompt = Data.define(:system, :messages, :cache_breakpoints) do
    def to_call_kwargs
      { system: system, messages: messages, cache_breakpoints: cache_breakpoints }
    end

    def to_s
      [system_text, messages_text].reject(&:empty?).join("\n\n")
    end

    private

    def system_text
      Array(system).map { _1.is_a?(Hash) ? _1[:text].to_s : _1.to_s }.join("\n\n---\n\n")
    end

    def messages_text
      Array(messages).map { "[#{_1[:role]}] #{_1[:content]}" }.join("\n\n")
    end
  end
end
