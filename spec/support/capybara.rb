require "capybara/rspec"
require "selenium/webdriver"

Capybara.register_driver :headless_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless=new")
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-dev-shm-usage")
  options.add_argument("--window-size=1400,1400")
  # Sin aviso de "contraseña filtrada": el de los specs (password1234) lo está, y
  # ese diálogo nativo aparece tras el login y se traga los clics siguientes
  options.add_preference("profile.password_manager_leak_detection", false)

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

Capybara.javascript_driver = :headless_chrome
Capybara.save_path = Rails.root.join("tmp/capybara")
