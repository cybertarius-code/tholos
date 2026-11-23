import { Controller } from "@hotwired/stimulus"

// SPK-0007 (prototipo): saldo diario con ECharts.
// La librería se importa al conectar, no al cargar la página: los controladores
// se cargan en todas las páginas y el pin lleva preload: false.
// Colores desde los tokens CSS (claro/oscuro) y se redibuja al cambiar el modo.
export default class extends Controller {
  static values = { series: Array, currency: String, label: String }

  async connect() {
    const started = performance.now()
    const { default: echarts } = await import("echarts")
    if (!this.element.isConnected) return

    this.echarts = echarts
    this.render()
    this.element.dataset.loadMs = Math.round(performance.now() - started)

    this.themeObserver = new MutationObserver(() => this.render())
    this.themeObserver.observe(document.documentElement, { attributes: true, attributeFilter: ["class"] })
    this.resizeObserver = new ResizeObserver(() => this.chart?.resize())
    this.resizeObserver.observe(this.element)
  }

  disconnect() {
    this.themeObserver?.disconnect()
    this.resizeObserver?.disconnect()
    this.chart?.dispose()
  }

  render() {
    const css = getComputedStyle(document.documentElement)
    const color = (name) => css.getPropertyValue(name).trim()
    const money = new Intl.NumberFormat("es-ES", { style: "currency", currency: this.currencyValue })

    this.chart?.dispose()
    this.chart = this.echarts.init(this.element, null, { renderer: "canvas" })
    this.chart.setOption({
      animation: false,
      aria: { enabled: true, label: { description: this.labelValue } },
      grid: { left: 8, right: 8, top: 16, bottom: 8, containLabel: true },
      tooltip: { trigger: "axis", valueFormatter: (cents) => money.format(cents / 100) },
      xAxis: {
        type: "time",
        axisLine: { lineStyle: { color: color("--color-line") } },
        axisLabel: { color: color("--color-ink"), hideOverlap: true }
      },
      yAxis: {
        type: "value",
        axisLabel: { color: color("--color-ink"), formatter: (cents) => money.format(cents / 100).replace(/,00/, "") },
        splitLine: { lineStyle: { color: color("--color-line"), opacity: 0.3 } }
      },
      series: [{
        type: "line",
        data: this.seriesValue,
        showSymbol: false,
        lineStyle: { color: color("--color-accent"), width: 2 },
        itemStyle: { color: color("--color-accent") },
        areaStyle: { color: color("--color-accent"), opacity: 0.08 }
      }]
    })
  }
}
