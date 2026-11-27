# Copiar un hogar a otro, en la misma o en otra base de datos (KB-0006).
# El volcado tiene datos financieros reales: guárdalo fuera del repositorio y
# de la bóveda, y bórralo cuando termines.
namespace :households do
  desc "Vuelca un hogar a JSON. Uso: bin/rails 'households:export[ID,RUTA]' (RUTA por defecto: tmp/hogar-ID-FECHA.json)"
  task :export, [ :household_id, :path ] => :environment do |_task, args|
    household = Household.find(args[:household_id].presence || abort("Falta el ID del hogar: bin/rails 'households:export[ID,RUTA]'"))
    path = args[:path].presence || Rails.root.join("tmp", "hogar-#{household.id}-#{Date.current.iso8601}.json").to_s

    dump = Households::Dump.call(household)
    File.write(path, JSON.pretty_generate(dump))
    File.chmod(0o600, path) # solo el dueño del fichero puede leerlo

    puts "Hogar #{household.id} (#{household.name}) volcado en #{path}: #{dump['accounts'].size} cuentas, " \
         "#{dump['categories'].size} categorías, #{dump['transactions'].size} movimientos, #{dump['fingerprints'].size} huellas"
  end

  desc "Carga un volcado en un hogar sin cuentas. Uso: bin/rails 'households:import[ID_DESTINO,RUTA]'"
  task :import, [ :household_id, :path ] => :environment do |_task, args|
    abort "Uso: bin/rails 'households:import[ID_DESTINO,RUTA]'" if args[:household_id].blank? || args[:path].blank?
    household = Household.find(args[:household_id])

    result = Households::Load.call(household, JSON.parse(File.read(args[:path])))

    puts "Hogar #{household.id} (#{household.name}): #{result.accounts} cuentas, #{result.categories} categorías nuevas, " \
         "#{result.transactions} movimientos"
    puts "Aviso: #{result.fingerprints_lost} huellas sin datos originales se han perdido" if result.fingerprints_lost.positive?
  rescue ArgumentError => e
    abort e.message
  end
end
