# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
# SPK-0007: builds parciales vendorizados (el pin de jspm no funciona con ninguna de las dos)
pin "echarts", to: "echarts.js", preload: false
pin "chartjs", to: "chartjs.js", preload: false
