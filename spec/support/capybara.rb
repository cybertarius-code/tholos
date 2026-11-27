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

# Chrome 158 rechaza el origen "*" en Storage.clearDataForOrigin ("* is not a valid
# URL"), y Capybara 3.40 lo usa al reiniciar la sesión tras cada system spec: fallan
# todos. Hasta que Capybara lo corrija, las cookies se borran con
# Network.clearBrowserCookies y el resto (localStorage) por el origen del servidor
# de los specs.
module ChromeStorageClearByOrigin
  def execute_cdp(cmd, **params)
    return super unless cmd == "Storage.clearDataForOrigin" && params[:origin] == "*"

    types = params[:storageTypes].to_s.split(",")
    super("Network.clearBrowserCookies") if types.delete("cookies")
    origin = Capybara.current_session.server&.base_url
    super(cmd, origin: origin, storageTypes: types.join(",")) if origin && types.any?
  end
end
Capybara::Selenium::Driver::ChromeDriver.prepend(ChromeStorageClearByOrigin)
