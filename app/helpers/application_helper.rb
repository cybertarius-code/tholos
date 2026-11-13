module ApplicationHelper
  THEMES = %w[system light dark].freeze

  def theme_preference
    preference = cookies[:theme]
    THEMES.include?(preference) ? preference : "system"
  end

  def dark_theme?
    theme_preference == "dark"
  end

  def system_theme?
    theme_preference == "system"
  end

  def nav_link_to(label, path)
    active = current_page?(path)

    link_to label, path,
      aria: (active ? { current: "page" } : {}),
      class: class_names(
        "flex min-h-11 w-full items-center rounded-lg px-3 py-2 text-sm font-medium transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ink",
        active ? "bg-ink text-white dark:bg-slate-100 dark:text-slate-900" : "text-slate-700 hover:bg-stone-100 dark:text-slate-200 dark:hover:bg-slate-800"
      )
  end
end
