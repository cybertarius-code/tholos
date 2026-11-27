import { Controller } from "@hotwired/stimulus"

// Modal "+ Movimiento" (US-0109). Se abre al llegar al frame "modal" y, al
// cerrarse (botón, Cancelar o Escape), vacía el frame y devuelve el foco al
// botón que lo abrió. <dialog> ya atrapa el foco y cierra con Escape.
export default class extends Controller {
  static values = { opener: String }

  connect() {
    if (!this.element.open) this.element.showModal()
  }

  // Al guardar, el Turbo Stream vacía el frame: el <dialog> sale del DOM abierto y sin
  // evento close. Si tras el cambio no queda otro modal (errores, pestañas), foco al botón.
  disconnect() {
    if (!this.element.open) return

    requestAnimationFrame(() => {
      if (!document.querySelector("dialog[open]")) document.getElementById(this.openerValue)?.focus()
    })
  }

  close() {
    this.element.close()
  }

  closed() {
    // Al sustituir el modal (errores, pestañas) el viejo sale del DOM: no hay nada que limpiar
    if (!this.element.isConnected) return

    const frame = this.element.closest("turbo-frame")
    frame.removeAttribute("src")
    frame.replaceChildren()
    document.getElementById(this.openerValue)?.focus()
  }
}
