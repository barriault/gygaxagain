RSpec.configure do |config|
  config.before(:each) do
    Llm::Providers::Anthropic.reset_client! if defined?(Llm::Providers::Anthropic)
  end
end
