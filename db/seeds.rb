# Seeds de demo: solo desarrollo local. Nunca en producción.
# Uso: bin/rails db:seed (idempotente, se puede repetir).

abort "Los seeds de demo no se ejecutan en producción" if Rails.env.production?

load Rails.root.join("db/seeds/demo.rb")
load Rails.root.join("db/seeds/performance.rb")
