import { Controller } from "@hotwired/stimulus"

const THEMES = ["system", "light", "dark"]
const THEME_COOKIE_MAX_AGE = 60 * 60 * 24 * 365

export default class extends Controller {
  connect() {
    this.systemTheme = window.matchMedia("(prefers-color-scheme: dark)")
    this.handleSystemThemeChange = this.handleSystemThemeChange.bind(this)
    this.systemTheme.addEventListener("change", this.handleSystemThemeChange)
  }

  disconnect() {
    this.systemTheme.removeEventListener("change", this.handleSystemThemeChange)
  }

  change(event) {
    const theme = event.currentTarget.value
    if (!THEMES.includes(theme)) throw new Error(`Unsupported theme: ${theme}`)

    document.documentElement.classList.toggle(
      "dark",
      theme === "dark" || (theme === "system" && this.systemTheme.matches)
    )

    const secure = window.location.protocol === "https:" ? "; secure" : ""
    document.cookie = `theme=${theme}; path=/; max-age=${THEME_COOKIE_MAX_AGE}; samesite=lax${secure}`
  }

  handleSystemThemeChange(event) {
    if (this.element.value === "system") {
      document.documentElement.classList.toggle("dark", event.matches)
    }
  }
}
