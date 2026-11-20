class CategoryIconComponent < ViewComponent::Base
  # Clases completas para que Tailwind las detecte
  RINGS = {
    "navy" => "ring-cat-navy", "teal" => "ring-cat-teal", "green" => "ring-cat-green", "gold" => "ring-cat-gold",
    "copper" => "ring-cat-copper", "red" => "ring-cat-red", "plum" => "ring-cat-plum", "slate" => "ring-cat-slate"
  }.freeze

  SWATCHES = {
    "navy" => "bg-cat-navy", "teal" => "bg-cat-teal", "green" => "bg-cat-green", "gold" => "bg-cat-gold",
    "copper" => "bg-cat-copper", "red" => "bg-cat-red", "plum" => "bg-cat-plum", "slate" => "bg-cat-slate"
  }.freeze

  def initialize(color:, icon:, size: :medium)
    @color = color
    @emoji = Category::ICONS.fetch(icon, Category::ICONS["tag"])
    @size = size
  end

  def call
    tag.span(@emoji, aria: { hidden: true }, class: class_names(
      "inline-flex shrink-0 items-center justify-center rounded-full bg-surface ring-2",
      RINGS.fetch(@color, RINGS["slate"]),
      @size == :small ? "size-7 text-sm" : "size-9 text-base"
    ))
  end
end
