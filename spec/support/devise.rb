RSpec.configure do |config|
  if defined?(Devise)
    config.include Devise::Test::IntegrationHelpers, type: :request
    config.include Devise::Test::IntegrationHelpers, type: :system
    config.include Devise::Test::ControllerHelpers, type: :controller
  end

  # Default request specs to apex host. Specs can override with host! "admin.gygaxagain.com".
  config.before(:each, type: :request) { host! "gygaxagain.com" }

  # When eager_load is false (default in test env), Devise.configure_warden! runs during
  # route-drawing before model classes are autoloaded, so no strategies get registered in
  # Warden's default_strategies. Re-run configure_warden! at suite start after all code
  # has loaded so that Warden knows about :database_authenticatable and :rememberable.
  config.before(:suite) do
    Devise.class_variable_set(:@@warden_configured, nil)
    Devise.configure_warden!
  end
end
