namespace :perf do
  desc "Hogar 'Rendimiento' con 8 cuentas y 10 000 movimientos para medir (US-0112). Idempotente; nunca en producción"
  task seed: :environment do
    # Antes de tocar la BD (y antes de cargar nada más)
    abort "perf:seed no se ejecuta en producción" if Rails.env.production?

    seed = PerformanceSeed.new
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    created = seed.call
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

    if created.zero?
      puts "perf:seed: el hogar \"#{seed.household.name}\" (id #{seed.household.id}) ya tiene movimientos; nada que hacer"
    else
      puts format("perf:seed: %d movimientos en el hogar \"%s\" (id %d) en %.1f s",
                  created, seed.household.name, seed.household.id, elapsed)
    end
    puts "perf:seed: usuario #{PerformanceSeed::EMAIL} (contraseña local, ver THOLOS_PERF_PASSWORD)"
  end
end
