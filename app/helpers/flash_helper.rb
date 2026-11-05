module FlashHelper
  VARIANTS = {
    "notice" => :success, "success" => :success,
    "alert"  => :error,   "error"   => :error,
    "warning" => :warning, "info"   => :info
  }.freeze

  STYLES = {
    success: { border: "border-l-success", icon: "text-success", delay: 4000 },
    info:    { border: "border-l-info",    icon: "text-info",    delay: 5000 },
    warning: { border: "border-l-warning", icon: "text-warning", delay: 8000 },
    error:   { border: "border-l-error",   icon: "text-error",   delay: 8000 }
  }.freeze

  ICONS = {
    success: "M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z",
    error:   "m9.75 9.75 4.5 4.5m0-4.5-4.5 4.5M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z",
    warning: "M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126ZM12 15.75h.008v.008H12v-.008Z",
    info:    "m11.25 11.25.041-.02a.75.75 0 0 1 1.063.852l-.708 2.836a.75.75 0 0 0 1.063.853l.041-.021M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9-3.75h.008v.008H12V8.25Z"
  }.freeze

  def flash_variant(type)
    VARIANTS.fetch(type.to_s, :info)
  end

  def flash_role(variant)
    %i[error warning].include?(variant) ? "alert" : "status"
  end

  def flash_icon(variant, css: "size-5 shrink-0")
    tag.svg(class: css, xmlns: "http://www.w3.org/2000/svg", fill: "none", viewBox: "0 0 24 24",
            "stroke-width": "1.5", stroke: "currentColor", "aria-hidden": "true") do
      tag.path(d: ICONS.fetch(variant), "stroke-linecap": "round", "stroke-linejoin": "round")
    end
  end
end
