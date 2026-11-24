# Seeds de rendimiento (US-0112): no se cargan con db:seed porque crean 10 000
# movimientos. Se generan aparte, solo en local:
#
#   bin/rails perf:seed   # hogar "Rendimiento", idempotente
#   bin/perf              # p95 de las listas en RAILS_ENV=production local
#
# Ver lib/performance_seed.rb.
