module TransactionsHelper
  # Cuentas abiertas; al editar, también la del movimiento aunque esté cerrada
  def transaction_account_options(transaction)
    accounts = Current.household.accounts.ordered.to_a
    accounts.select { |account| account.open? || account.id == transaction.account_id }
      .map { |account| [ "#{account.name} (#{account.currency})", account.id ] }
  end

  # <optgroup> por padre, con el padre como primera opción y sus hijas debajo.
  # Cada grupo lleva data-kind para que el formulario muestre solo los del tipo elegido.
  def transaction_category_options(transaction)
    categories = Current.household.categories.ordered.to_a
    visible = categories.select { |category| !category.archived? || category.id == transaction.category_id }
    children = visible.reject(&:root?).group_by(&:parent_id)

    groups = visible.select(&:root?).map do |root|
      options = [ root, *children.fetch(root.id, []) ].map do |category|
        label = category.root? ? t("transactions.form.category_general", name: category.name) : category.name
        tag.option(label, value: category.id, selected: category.id == transaction.category_id)
      end
      tag.optgroup(safe_join(options), label: root.name, data: { kind: root.kind })
    end

    safe_join([ tag.option(t("transactions.form.no_category"), value: ""), *groups ])
  end

  def transaction_status_options
    Transaction::STATUSES.reverse.map { |status| [ t("transactions.statuses.#{status}"), status ] }
  end
end
