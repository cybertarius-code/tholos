class ButtonComponent < ViewComponent::Base
  VARIANTS = {
    primary: "bg-ink text-white hover:bg-slate-700 dark:bg-slate-700 dark:text-slate-100 dark:hover:bg-slate-600",
    secondary: "border border-line bg-surface text-ink hover:bg-stone-50 dark:hover:bg-slate-800",
    danger: "bg-error text-white hover:bg-red-800 dark:text-slate-950 dark:hover:bg-red-300",
    ghost: "bg-transparent text-ink hover:bg-stone-100 dark:hover:bg-slate-800"
  }.freeze

  SIZES = {
    small: "px-3 py-1.5 text-sm",
    medium: "px-3.5 py-2.5 text-sm",
    large: "px-5 py-3 text-base"
  }.freeze

  def initialize(variant: :primary, size: :medium, disabled: false, href: nil, type: "button", **html_attributes)
    @variant = variant.to_sym
    @size = size.to_sym
    @disabled = disabled
    @href = href
    @type = type
    @html_attributes = html_attributes

    raise ArgumentError, "Unknown button variant: #{variant}" unless VARIANTS.key?(@variant)
    raise ArgumentError, "Unknown button size: #{size}" unless SIZES.key?(@size)
  end

  def component_attributes
    attributes = @html_attributes.except(:class)
    attributes[:class] = class_names(
      "inline-flex min-h-11 items-center justify-center rounded-md font-medium transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2",
      VARIANTS.fetch(@variant),
      SIZES.fetch(@size),
      @disabled ? "cursor-not-allowed opacity-50" : "cursor-pointer",
      @html_attributes[:class]
    )

    if @href
      attributes[:href] = @disabled ? nil : @href
      attributes[:aria] = (attributes[:aria] || {}).merge(disabled: true) if @disabled
      attributes[:tabindex] = -1 if @disabled
    else
      attributes[:type] = @type
      attributes[:disabled] = true if @disabled
    end

    attributes
  end
end
