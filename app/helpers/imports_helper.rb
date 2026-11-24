module ImportsHelper
  # Decisión de una fila: "Sin decidir", "Omitir", las categorías activas en
  # dos grupos, gastos e ingresos (la categoría da el tipo, como en US-0104), y
  # (US-0114) "Transferencia a/desde" otra cuenta y "Ya registrado"
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
      *groups,
      import_transfer_group(row),
      import_recorded_group(row)
    ].compact)
  end

  # Texto de la decisión de una fila bloqueada o confirmada
  def import_decision_label(row)
    if row.skipped? then t("imports.row.skip")
    elsif row.transfer?
      name = import_accounts_by_id[row.counter_account_id]&.name
      row.amount_cents.negative? ? t("imports.row.transfer_to", name: name) : t("imports.row.transfer_from", name: name)
    elsif row.already_recorded? then t("imports.row.already_recorded")
    else row.category&.name
    end
  end

  private
    # Cuentas activas del hogar, de la misma moneda y distintas de la importada.
    # El signo de la fila da la dirección.
    def import_transfer_group(row)
      imported = import_accounts_by_id.fetch(row.import.account_id)
      accounts = import_accounts_by_id.values.select do |account|
        account.id != imported.id && account.currency == imported.currency && (account.open? || account.id == row.counter_account_id)
      end
      return if accounts.empty?

      options = accounts.map do |account|
        tag.option(account.name, value: "transfer:#{account.id}", selected: account.id == row.counter_account_id)
      end
      label = row.amount_cents.to_i.negative? ? t("imports.row.transfer_to_group") : t("imports.row.transfer_from_group")
      tag.optgroup(safe_join(options), label: label)
    end

    # Movimientos de la cuenta con el mismo importe, sin huella y a ± 7 días
    def import_recorded_group(row)
      candidates = import_candidates(row.import).select do |movement|
        movement.amount_cents == row.amount_cents && row.date && (movement.date - row.date).abs <= ImportRow::MATCH_WINDOW
      end
      return if candidates.empty?

      options = candidates.map do |movement|
        description = movement.payee.presence || movement.notes.presence ||
          (movement.transfer_id ? t("imports.row.transfer_movement") : t("imports.row.movement"))
        label = "#{l(movement.date, format: :short)} · #{description} · #{MoneyComponent.new(cents: movement.amount_cents, currency: movement.currency).formatted_amount}"
        tag.option(label, value: "recorded:#{movement.id}", selected: movement.id == row.matched_transaction_id)
      end
      tag.optgroup(safe_join(options), label: t("imports.row.already_recorded_group"))
    end

    # Una consulta por importación: todos los candidatos de todas sus filas
    def import_candidates(import)
      @import_candidates ||= {}
      @import_candidates[import.id] ||= begin
        rows = ImportRow.where(import_id: import.id).where(proposal: "none")
        range = rows.pick(Arel.sql("MIN(date) - #{ImportRow::MATCH_WINDOW}"), Arel.sql("MAX(date) + #{ImportRow::MATCH_WINDOW}"))
        if range.compact.size == 2
          Transaction.where(account_id: import.account_id, household_id: import.household_id, import_ref: nil, date: range[0]..range[1])
            .where(amount_cents: rows.select(:amount_cents)).order(:date, :id).to_a
        else
          []
        end
      end
    end

    def import_accounts_by_id
      @import_accounts_by_id ||= Current.household.accounts.ordered.to_a.index_by(&:id)
    end

    # Una consulta por petición, aunque haya muchas filas
    def import_categories
      @import_categories ||= Current.household.categories.ordered.to_a
    end
end
