RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :headless_chrome
    # El rate limit del login cuenta en Rails.cache (memory_store) y todos los
    # system specs entran desde 127.0.0.1: sin limpiar, el login 11 falla
    Rails.cache.clear
  end
end
