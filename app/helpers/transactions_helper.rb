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

  # --- Lista de movimientos (US-0106) ---

  def transaction_search_account_options(search)
    search.accounts.map do |account|
      label = account.closed? ? t("transactions.index.closed_account", name: account.name) : account.name
      [ label, account.id ]
    end
  end

  # Un padre filtra también por sus hijas; las archivadas siguen para buscar en el histórico
  def transaction_search_category_options(search)
    categories = search.categories
    selected = search.category&.id
    children = categories.reject(&:root?).group_by(&:parent_id)

    groups = categories.select(&:root?).map do |root|
      options = [ root, *children.fetch(root.id, []) ].map do |category|
        label = category.root? ? t("transactions.index.category_all", name: category.name) : category.name
        label = t("transactions.index.archived", name: label) if category.archived?
        tag.option(label, value: category.id, selected: category.id == selected)
      end
      tag.optgroup(safe_join(options), label: "#{root.name} · #{t("categories.kinds.#{root.kind}")}")
    end

    safe_join([ tag.option(t("transactions.index.any_category"), value: ""), *groups ])
  end

  def transaction_search_status_options
    [ [ t("transactions.index.any_status"), "" ] ] + transaction_status_options
  end

  # Enlace a la edición: un lado de una transferencia se edita en la transferencia
  def edit_movement_path(transaction)
    transaction.transfer? ? edit_transfer_path(transaction.transfer_id) : edit_transaction_path(transaction)
  end

  # "Mercadona", "Alimentación", "Sin beneficiario", "Transferencia a/desde" o "Ajuste de saldo"
  def movement_title(transaction, search)
    if transaction.transfer?
      transaction.amount_cents.negative? ? t("accounts.show.transfer_to") : t("accounts.show.transfer_from")
    elsif transaction.adjustment?
      t("accounts.show.balance_adjustment")
    else
      transaction.payee.presence || movement_category(transaction, search)&.name || t("accounts.show.no_payee")
    end
  end

  # La cuenta del otro lado de una transferencia
  def transfer_counterpart_account(transaction, search)
    other = transaction.transfer&.counterpart_of(transaction)
    search.accounts_by_id[other.account_id] if other
  end

  def movement_account(transaction, search)
    search.accounts_by_id.fetch(transaction.account_id)
  end

  def movement_category(transaction, search)
    search.categories_by_id[transaction.category_id] if transaction.category_id
  end

  def movement_badges(transaction)
    badges = []
    badges << render(BadgeComponent.new) { t("transactions.index.transfer") } if transaction.transfer?
    badges << render(BadgeComponent.new) { t("transactions.index.adjustment") } if transaction.adjustment?
    unless transaction.cleared?
      variant = transaction.pending? ? :warning : :neutral
      badges << render(BadgeComponent.new(variant: variant)) { t("transactions.statuses.#{transaction.status}") }
    end
    safe_join(badges, " ")
  end

  # Saldo después del movimiento: solo con una cuenta filtrada y en lo conciliado
  def running_balance_for(transaction)
    return unless transaction.has_attribute?(:running_balance_cents) && transaction.cleared?

    transaction.running_balance_cents
  end
end
