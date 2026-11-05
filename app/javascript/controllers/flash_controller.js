import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { delay: { type: Number, default: 5000 } }

  connect() { this.start() }
  disconnect() { this.clear() }

  pause() { this.clear() }
  resume() { this.start() }

  close() {
    this.clear()
    this.element.dataset.state = "closed"
    setTimeout(() => this.element.remove(), 200)
  }

  start() {
    this.clear()
    if (this.delayValue > 0) this.timeout = setTimeout(() => this.close(), this.delayValue)
  }

  clear() { clearTimeout(this.timeout) }
}
