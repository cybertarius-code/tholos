# Filtros de la lista de movimientos (US-0106): mes, cuenta, categoría (el padre
# incluye sus hijas, ADR-0015), estado y texto en beneficiario o notas.
#
# Con una sola cuenta filtrada, cada fila trae `running_balance_cents`: el saldo
# de la cuenta después del movimiento. Se calcula con una window function sobre
# TODO el histórico de la cuenta en una subconsulta, y solo después se filtra y
# se pagina; si se calculara sobre la página, saldría mal.
#
# El saldo acumulado sigue la regla del saldo actual (ADR-0005): suma solo lo
# conciliado. Así, en el último movimiento conciliado coincide con el saldo de
# la cuenta. Las filas pendientes o programadas no lo muestran.
class TransactionSearch
  include ActiveModel::Model
  include ActiveModel::Attributes

  MONTH_FORMAT = /\A\d{4}-(0[1-9]|1[0-2])\z/

  attribute :month, :string
  attribute :account_id, :integer
  attribute :category_id, :integer
  attribute :status, :string
  attribute :q, :string

  attr_reader :household

  def initialize(household:, **attributes)
    @household = household
    super(**attributes)
  end

  def month
    value = super
    value.to_s.match?(MONTH_FORMAT) ? value : Date.current.strftime("%Y-%m")
  end

  def month_start
    Date.strptime(month, "%Y-%m")
  end

  # Cuentas y categorías del hogar, cargadas una vez: sirven para los
  # desplegables de filtros, las filas y el otro lado de las transferencias,
  # sin una consulta por relación (presupuesto de US-0112: < 15 consultas)
  def accounts
    @accounts ||= household.accounts.ordered.to_a
  end

  def categories
    @categories ||= household.categories.ordered.to_a
  end

  def accounts_by_id
    @accounts_by_id ||= accounts.index_by(&:id)
  end

  def categories_by_id
    @categories_by_id ||= categories.index_by(&:id)
  end

  def account
    accounts_by_id[account_id] if account_id
  end

  def category
    categories_by_id[category_id] if category_id
  end

  def status
    super.presence_in(Transaction::STATUSES)
  end

  def q
    super.to_s.squish.presence
  end

  def running_balance?
    account.present?
  end

  # La cuenta y la categoría filtradas existen y son del hogar
  def valid_references?
    (account_id.nil? || account.present?) && (category_id.nil? || category.present?)
  end

  # Filtros distintos del mes, para "Quitar filtros" y el estado vacío
  def filtered?
    [ account_id, category_id, status, q ].any?(&:present?)
  end

  # Parámetros de la URL, sin los vacíos
  def to_params
    { month: month, account_id: account&.id, category_id: category&.id, status: status, q: q }.compact
  end

  def results
    scope = base
      .where(date: month_start..month_start.end_of_month)
      .includes(transfer: :legs)
      .with_attached_receipt
      .order(date: :desc, id: :desc)
    scope = scope.where(category_id: category_ids) if category_id
    scope = scope.where(status: status) if status
    scope = scope.where("transactions.payee ILIKE :q OR transactions.notes ILIKE :q", q: "%#{Transaction.sanitize_sql_like(q)}%") if q
    scope
  end

  private
    # Una cuenta de otro hogar o inexistente no da resultados (el controlador
    # responde 404 antes)
    def base
      return household.transactions unless account_id
      return Transaction.none unless account

      Transaction.from(with_running_balance, :transactions)
    end

    def with_running_balance
      cleared_sum = <<~SQL.squish
        COALESCE(SUM(amount_cents) FILTER (WHERE status = 'cleared')
          OVER (PARTITION BY account_id ORDER BY date, id), 0)
      SQL
      household.transactions.where(account_id: account.id)
        .select("transactions.*", Arel.sql("#{account.opening_balance_cents.to_i} + #{cleared_sum} AS running_balance_cents"))
    end

    # El padre incluye sus hijas; una categoría de otro hogar no da resultados
    def category_ids
      return [] unless category

      [ category.id, *categories.select { |child| child.parent_id == category.id }.map(&:id) ]
    end
end
