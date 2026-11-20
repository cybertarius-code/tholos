import { Controller } from "@hotwired/stimulus"

// Cambia la etiqueta del importe inicial según el tipo de cuenta:
// en tarjetas y préstamos se pide la deuda en positivo.
export default class extends Controller {
  static targets = ["kind", "amountLabel"]
  static values = { liabilityKinds: Array, balanceLabel: String, debtLabel: String }

  connect() {
    this.update()
  }

  update() {
    const liability = this.liabilityKindsValue.includes(this.kindTarget.value)
    this.amountLabelTarget.textContent = liability ? this.debtLabelValue : this.balanceLabelValue
  }
}
