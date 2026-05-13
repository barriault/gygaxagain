require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Gygaxagain
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil

    # Disable CSRF Origin-header check. Our subdomain architecture (admin.*
    # posting to apex.* for sign-in / sign-out via shared session cookie) is
    # same-site but cross-origin, which Rails' default Origin check rejects.
    # Token-based CSRF protection (authenticity_token) remains active and is
    # the primary defense.
    config.action_controller.forgery_protection_origin_check = false

    # Allow cross-host `redirect_to`. Our subdomain architecture has several
    # legitimate apex<->admin redirects (sign-in success, sign-out success,
    # require_no_authentication, future Devise + Pundit flows). The default
    # `raise_on_open_redirects = true` (Rails 8.0+) requires `allow_other_host:`
    # on every call, which is whack-a-mole for Devise's internal filters.
    # We don't have any user-controlled redirect targets in this codebase
    # (all redirects are to known internal URLs), so the protection adds
    # friction without preventing a real threat for our use case.
    config.action_controller.raise_on_open_redirects = false
  end
end
