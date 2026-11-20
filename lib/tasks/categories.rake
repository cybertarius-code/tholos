namespace :categories do
  desc "Crea las categorías por defecto que falten en un hogar (idempotente). Uso: bin/rails 'categories:seed_defaults[ID]'"
  task :seed_defaults, [ :household_id ] => :environment do |_task, args|
    household_id = args[:household_id].presence || abort("Falta el ID del hogar: bin/rails 'categories:seed_defaults[ID]'")
    household = Household.find(household_id)

    created = household.seed_default_categories!
    puts "Hogar #{household.id} (#{household.name}): #{created} categorías por defecto creadas"
  end
end
