module ImportsHelper
  # Decisión de una fila: "Sin decidir", "Omitir" y las categorías activas en
  # dos grupos, gastos e ingresos (la categoría da el tipo, como en US-0104)
  def import_decision_options(row)
    categories = import_categories
    names = categories.index_by(&:id)
    groups = Category::KINDS.map do |kind|
      options = categories.select { |category| category.kind == kind && (!category.archived? || category.id == row.category_id) }.map do |category|
        label = category.root? ? category.name : "#{names[category.parent_id]&.name} › #{category.name}"
        tag.option(label, value: category.id, selected: category.id == row.category_id)
      end
      tag.optgroup(safe_join(options), label: t("imports.row.kinds.#{kind}"))
    end

    safe_join([
      tag.option(t("imports.row.undecided"), value: "", selected: row.undecided?),
      tag.option(t("imports.row.skip"), value: "skip", selected: row.skipped?),
      *groups
    ])
  end

  private
    # Una consulta por petición, aunque haya muchas filas
    def import_categories
      @import_categories ||= Current.household.categories.ordered.to_a
    end
end
