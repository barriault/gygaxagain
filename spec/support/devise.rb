RSpec.configure do |config|
  if defined?(Devise)
    config.include Devise::Test::IntegrationHelpers, type: :request
    config.include Devise::Test::IntegrationHelpers, type: :system
    config.include Devise::Test::ControllerHelpers, type: :controller
  end

  # Default request specs to apex host. Specs can override with host! "admin.gygaxagain.com".
  config.before(:each, type: :request) { host! "gygaxagain.com" }

  # When eager_load is false (default in test env), Devise.configure_warden! runs
  # during route-drawing before the Warden::Manager middleware block has assigned
  # Devise.warden_config, so scope_defaults is never called for the :user scope.
  # Re-run configure_warden! at suite start after all code has loaded so that
  # Warden knows about :database_authenticatable and :rememberable.
  #
  # NOTE: depends on Devise internals (@@warden_configured class var). If a future
  # Devise upgrade renames or removes it, fail fast with a clear error rather than
  # silently no-oping.
  config.before(:suite) do
    if Devise.class_variable_defined?(:@@warden_configured)
      Devise.class_variable_set(:@@warden_configured, nil)
    end
    Devise.configure_warden!
  end
end
