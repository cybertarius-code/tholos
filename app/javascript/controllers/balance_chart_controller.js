import { Controller } from "@hotwired/stimulus"

// Gráfico de saldo diario con Chart.js (ADR-0019).
// - La librería se importa al conectar: los controladores se cargan en todas
//   las páginas y el pin lleva preload: false, así que solo la descargan las
//   páginas con gráfico.
// - Datos del servidor: pares [fecha ISO, céntimos].
// - Colores desde los tokens CSS; se redibuja al cambiar claro/oscuro.
// - El canvas no es accesible: el resumen va en aria-label y los datos en una
//   tabla junto al gráfico.
export default class extends Controller {
  static targets = ["canvas"]
  static values = { series: Array, currency: String, locale: { type: String, default: "es-ES" } }

  async connect() {
    const { default: Chart } = await import("chartjs")
    if (!this.element.isConnected) return

    this.Chart = Chart
    this.render()
    this.themeObserver = new MutationObserver(() => this.render())
    this.themeObserver.observe(document.documentElement, { attributes: true, attributeFilter: ["class"] })
  }

  disconnect() {
    this.themeObserver?.disconnect()
    this.chart?.destroy()
    this.chart = null
  }

  render() {
    const css = getComputedStyle(document.documentElement)
    const color = (name) => css.getPropertyValue(name).trim()
    const money = new Intl.NumberFormat(this.localeValue, { style: "currency", currency: this.currencyValue })
    const compact = new Intl.NumberFormat(this.localeValue, { style: "currency", currency: this.currencyValue, maximumFractionDigits: 0 })
    const day = new Intl.DateTimeFormat(this.localeValue, { day: "numeric", month: "short", timeZone: "UTC" })
    const accent = color("--color-accent")
    const narrow = this.element.clientWidth < 480

    this.chart?.destroy()
    this.chart = new this.Chart(this.canvasTarget, {
      type: "line",
      data: {
        labels: this.seriesValue.map(([date]) => day.format(new Date(date))),
        datasets: [{
          data: this.seriesValue.map(([, cents]) => cents),
          borderColor: accent,
          backgroundColor: withAlpha(accent, 0.1),
          fill: true,
          pointRadius: 0,
          pointHoverRadius: 3,
          borderWidth: 2,
          tension: 0
        }]
      },
      options: {
        animation: false,
        responsive: true,
        maintainAspectRatio: false,
        interaction: { mode: "index", intersect: false },
        plugins: { tooltip: { callbacks: { label: (item) => minus(money.format(item.raw / 100)) } } },
        scales: {
          x: {
            ticks: { color: color("--color-ink"), maxTicksLimit: narrow ? 4 : 6, maxRotation: 0, autoSkipPadding: 16 },
            grid: { display: false }
          },
          y: {
            ticks: { color: color("--color-ink"), maxTicksLimit: 6, callback: (cents) => minus(compact.format(cents / 100)) },
            grid: { color: withAlpha(color("--color-line"), 0.3) }
          }
        }
      }
    })
  }
}

// Los tokens son hexadecimales (#rrggbb); color-mix() no vale en todos los canvas
function withAlpha(hex, alpha) {
  const value = hex.replace("#", "")
  if (!/^[0-9a-f]{6}$/i.test(value)) return hex
  const [r, g, b] = [0, 2, 4].map((start) => parseInt(value.slice(start, start + 2), 16))
  return `rgba(${r}, ${g}, ${b}, ${alpha})`
}

// Signo menos tipográfico, como MoneyComponent
function minus(text) {
  return text.replace(/^-/, "−")
}
