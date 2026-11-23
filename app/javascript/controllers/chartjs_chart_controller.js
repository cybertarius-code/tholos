import { Controller } from "@hotwired/stimulus"

// SPK-0007 (prototipo): el mismo gráfico con Chart.js, para comparar.
export default class extends Controller {
  static targets = ["canvas"]
  static values = { series: Array, currency: String, label: String }

  async connect() {
    const started = performance.now()
    const { default: Chart } = await import("chartjs")
    if (!this.element.isConnected) return

    this.Chart = Chart
    this.render()
    this.element.dataset.loadMs = Math.round(performance.now() - started)

    this.themeObserver = new MutationObserver(() => this.render())
    this.themeObserver.observe(document.documentElement, { attributes: true, attributeFilter: ["class"] })
  }

  disconnect() {
    this.themeObserver?.disconnect()
    this.chart?.destroy()
  }

  render() {
    const css = getComputedStyle(document.documentElement)
    const color = (name) => css.getPropertyValue(name).trim()
    const money = new Intl.NumberFormat("es-ES", { style: "currency", currency: this.currencyValue })
    const day = new Intl.DateTimeFormat("es-ES", { day: "numeric", month: "short" })

    this.chart?.destroy()
    this.canvasTarget.setAttribute("aria-label", this.labelValue)
    this.chart = new this.Chart(this.canvasTarget, {
      type: "line",
      data: {
        labels: this.seriesValue.map(([date]) => day.format(new Date(date))),
        datasets: [{
          data: this.seriesValue.map(([, cents]) => cents),
          borderColor: color("--color-accent"),
          backgroundColor: color("--color-accent") + "14",
          fill: true,
          pointRadius: 0,
          borderWidth: 2
        }]
      },
      options: {
        animation: false,
        responsive: true,
        maintainAspectRatio: false,
        interaction: { mode: "index", intersect: false },
        plugins: { tooltip: { callbacks: { label: (item) => money.format(item.raw / 100) } } },
        scales: {
          x: { ticks: { color: color("--color-ink"), maxTicksLimit: 6 }, grid: { display: false } },
          y: {
            ticks: { color: color("--color-ink"), callback: (cents) => money.format(cents / 100).replace(/,00/, "") },
            grid: { color: color("--color-line") + "4d" }
          }
        }
      }
    })
  }
}
