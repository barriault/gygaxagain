require "capybara/rails"
require "capybara/rspec"

Capybara.default_host = "http://gygaxagain.com"
Capybara.app_host = "http://gygaxagain.com"
Capybara.always_include_port = true
Capybara.server = :puma, { Silent: true }
