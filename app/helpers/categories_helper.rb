module CategoriesHelper
  def category_kind_label(kind)
    t("categories.kinds.#{kind}")
  end

  def category_report_group_label(group)
    t("categories.report_groups.#{group}")
  end

  def category_report_group_options
    Category::REPORT_GROUPS.map { |group| [ category_report_group_label(group), group ] }
  end

  def category_color_label(color)
    t("categories.colors.#{color}")
  end

  # Padres activos del mismo tipo a los que puede pertenecer (sin ella misma)
  def category_parent_options(category)
    roots = Current.household.categories.active.roots.where(kind: category.kind).where.not(id: category.id).ordered
    roots.map { |root| [ root.name, root.id ] }
  end

  # "Transporte › Gasolina" para una hija; el nombre a secas para un padre
  def category_full_name(category, names)
    parent = names[category.parent_id]
    parent ? "#{parent.name} › #{category.name}" : category.name
  end
end
