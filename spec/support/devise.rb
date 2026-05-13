RSpec.configure do |config|
  if defined?(Devise)
    config.include Devise::Test::IntegrationHelpers, type: :request
    config.include Devise::Test::IntegrationHelpers, type: :system
    config.include Devise::Test::ControllerHelpers, type: :controller
  end

  # Default request specs to apex host. Specs can override with host! "admin.gygaxagain.com".
  config.before(:each, type: :request) { host! "gygaxagain.com" }
end
