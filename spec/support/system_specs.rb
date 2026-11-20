RSpec.configure do |config|
  # Sin el CSS compilado las páginas salen sin estilos y los specs de
  # maquetación pueden pasar sin comprobar nada (CI no lo compila solo)
  config.before(:suite) do
    if RSpec.world.example_groups.any? { |group| group.metadata[:type] == :system } &&
        !Rails.root.join("app/assets/builds/tailwind.css").exist?
      raise "Falta app/assets/builds/tailwind.css: ejecuta bin/rails tailwindcss:build"
    end
  end

  config.before(:each, type: :system) do
    driven_by :headless_chrome
    # El rate limit del login cuenta en Rails.cache (memory_store) y todos los
    # system specs entran desde 127.0.0.1: sin limpiar, el login 11 falla
    Rails.cache.clear
  end
end
