import { Controller } from "@hotwired/stimulus"

// Atajo de teclado de un botón o enlace (US-0109): pulsa el elemento al
// recibir su tecla (aria-keyshortcuts), salvo si se está escribiendo en un
// campo o ya hay un modal abierto.
export default class extends Controller {
  press(event) {
    if (event.key !== this.element.getAttribute("aria-keyshortcuts")) return
    if (event.ctrlKey || event.metaKey || event.altKey || event.defaultPrevented) return
    if (event.target.isContentEditable || event.target.closest?.("input, textarea, select")) return
    if (document.querySelector("dialog[open]")) return

    event.preventDefault()
    this.element.focus()
    this.element.click()
  }
}
