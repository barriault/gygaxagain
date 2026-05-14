module Llm
  class Error < StandardError; end

  class ConfigError < Error; end

  class ProviderError < Error
    attr_reader :provider_class, :provider_message

    def initialize(provider_class:, provider_message:)
      @provider_class   = provider_class
      @provider_message = provider_message
      super("[#{provider_class}] #{provider_message}")
    end
  end
end
