class BadgeComponent < ViewComponent::Base
  VARIANTS = {
    neutral: "bg-stone-100 text-stone-700 dark:bg-slate-700 dark:text-slate-100",
    success: "bg-green-50 text-success dark:bg-slate-800",
    warning: "bg-amber-50 text-warning dark:bg-slate-800",
    error: "bg-red-50 text-error dark:bg-slate-800"
  }.freeze

  def initialize(variant: :neutral)
    @variant = variant.to_sym
    raise ArgumentError, "Unknown badge variant: #{variant}" unless VARIANTS.key?(@variant)
  end

  def component_classes
    class_names("inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium", VARIANTS.fetch(@variant))
  end
end
