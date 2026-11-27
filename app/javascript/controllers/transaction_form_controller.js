import { Controller } from "@hotwired/stimulus"

// Muestra solo las categorías del tipo elegido (Gasto/Ingreso).
// Sin JavaScript se ven todas, y el modelo acepta cualquiera (devoluciones).
// En el modal (US-0109) el tipo llega en un campo oculto, fijado por la pestaña.
export default class extends Controller {
  static targets = ["direction", "category"]

  connect() {
    this.filter()
  }

  filter() {
    const checked = this.directionTargets.find((input) => input.checked || input.type === "hidden")
    if (!checked) return

    let selectedHidden = false
    this.categoryTarget.querySelectorAll("optgroup").forEach((group) => {
      const hidden = group.dataset.kind !== checked.value
      group.hidden = hidden
      group.disabled = hidden
      if (hidden && group.querySelector("option:checked")) selectedHidden = true
    })
    if (selectedHidden) this.categoryTarget.value = ""
  }
}
