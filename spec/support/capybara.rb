require "capybara/rails"
require "capybara/rspec"
require "selenium-webdriver"

Capybara.default_host = "http://gygaxagain.com"
Capybara.app_host = "http://gygaxagain.com"
Capybara.always_include_port = true
Capybara.server = :puma, { Silent: true }

Capybara.register_driver :selenium_chrome_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless=new")
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-gpu")
  options.add_argument("--window-size=1400,1000")
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

Capybara.javascript_driver = :selenium_chrome_headless

# Per-example: examples tagged with js: true use the JS driver.
RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by(:rack_test)
  end

  config.before(:each, type: :system, js: true) do
    driven_by(Capybara.javascript_driver)
  end
end
