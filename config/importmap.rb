# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
# Chart.js (ADR-0019): build parcial vendorizado, ver script/vendor/chartjs. Sin
# precarga: solo lo descargan las páginas con gráfico, con import() dinámico.
pin "chartjs", to: "chartjs.js", preload: false
