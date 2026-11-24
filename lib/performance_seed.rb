# Seed de rendimiento (US-0112): un hogar "Rendimiento" con 8 cuentas, las
# categorías por defecto y 10 000 movimientos repartidos en 3 años, para medir
# las listas con bin/perf antes de tener ese volumen real.
#
# - Determinista: Random.new(42) y fechas relativas a `today`.
# - Rápido: insert_all por lotes, sin validaciones ni callbacks. Respeta los
#   CHECK y las FK de la BD (importe distinto de cero, un solo tipo, moneda de
#   la cuenta, hogar), que la BD comprueba igualmente.
# - Idempotente: si el hogar ya tiene movimientos, no hace nada.
# - Todo o nada: una única transacción.
# - Nunca en producción.
#
# Uso: bin/rails perf:seed (o PerformanceSeed.new(total: 500).call en specs).
class PerformanceSeed
  class ProductionError < StandardError; end

  EMAIL = "perf@tholos.local".freeze
  HOUSEHOLD_NAME = "Rendimiento".freeze
  YEARS = 3
  BATCH_SIZE = 1_000

  ACCOUNTS = [
    { name: "Corriente BBVA", kind: "checking", opening: 250_000 },
    { name: "Corriente Sabadell", kind: "checking", opening: 120_000 },
    { name: "Ahorro", kind: "savings", opening: 1_500_000 },
    { name: "Efectivo", kind: "cash", opening: 15_000 },
    { name: "Visa", kind: "credit_card", opening: -45_000 },
    { name: "Mastercard", kind: "credit_card", opening: -12_000 },
    { name: "Préstamo coche", kind: "loan", opening: -1_200_000 },
    { name: "Fondo indexado", kind: "investment", opening: 800_000 }
  ].freeze

  # Dónde caen los gastos y con qué peso
  EXPENSE_ACCOUNTS = { "Corriente BBVA" => 5, "Visa" => 3, "Efectivo" => 2, "Mastercard" => 1, "Corriente Sabadell" => 1 }.freeze

  PAYEES = [
    "Mercadona", "Lidl", "Carrefour", "Día", "Repsol", "Cepsa", "Renfe", "Metro de Madrid", "Amazon",
    "El Corte Inglés", "Zara", "Decathlon", "Farmacia", "Iberdrola", "Endesa", "Movistar", "Netflix",
    "Spotify", "Bar Manolo", "Restaurante La Tasca", "Telepizza", "Ikea", "Leroy Merlin", "Cabify", nil
  ].freeze

  NOTES = [ nil, nil, nil, nil, "Compra semanal", "Regalo", "Con tarjeta", "Pagado a medias", "Revisar" ].freeze

  attr_reader :total, :today, :household

  def initialize(total: 10_000, today: Date.current, password: ENV.fetch("THOLOS_PERF_PASSWORD", "tholos-perf-local"))
    @total = total
    @today = today
    @password = password
    @random = Random.new(42)
  end

  # Devuelve el número de movimientos creados (0 si ya existían)
  def call
    raise ProductionError, "El seed de rendimiento no se ejecuta en producción" if Rails.env.production?

    ActiveRecord::Base.transaction do
      @household = find_or_create_household
      @household.seed_default_categories!
      next 0 if Transaction.exists?(household_id: @household.id)

      create_accounts
      insert_movements
    end
  end

  private
    def find_or_create_household
      user = User.includes(:households).find_by(email_address: EMAIL)
      user ||= User.create_with_household!(email: EMAIL, password: @password, household_name: HOUSEHOLD_NAME).then do |created|
        User.includes(:households).find(created.id)
      end
      user.households.find { |household| household.name == HOUSEHOLD_NAME } || user.households.first
    end

    def start_date
      today.prev_year(YEARS) + 1
    end

    def create_accounts
      @accounts = ACCOUNTS.each_with_index.to_h do |attributes, position|
        account = Account.create!(household: @household, name: attributes[:name], kind: attributes[:kind], currency: "EUR",
                                  opening_balance_cents: attributes[:opening], opening_date: start_date, position: position)
        [ account.name, account ]
      end
    end

    # Reparto: ~5 % de lados de transferencia, ~0,5 % ajustes, ~2 % ingresos y
    # el resto gastos. Hasta completar exactamente `total` filas.
    def insert_movements
      transfer_count = (total * 0.025).floor # dos lados cada una: ~5 % de filas
      adjustment_count = [ (total * 0.005).floor, 1 ].max
      income_count = (total * 0.02).floor
      expense_count = total - 2 * transfer_count - adjustment_count - income_count

      rows = []
      rows.concat(Array.new(expense_count) { expense_row })
      rows.concat(Array.new(income_count) { income_row })
      rows.concat(Array.new(adjustment_count) { adjustment_row })
      rows.concat(transfer_rows(transfer_count))

      rows.sort_by! { |row| [ row[:date], row[:amount_cents] ] }
      rows.each_slice(BATCH_SIZE) { |batch| Transaction.insert_all!(batch) }
      rows.size
    end

    def expense_row
      category = expense_categories.sample(random: @random)
      account = @accounts.fetch(weighted(EXPENSE_ACCOUNTS))
      movement(account, -cents(300, 15_000), category_id: category.id, payee: PAYEES.sample(random: @random),
               notes: NOTES.sample(random: @random))
    end

    def income_row
      category = income_categories.sample(random: @random)
      movement(@accounts.fetch("Corriente BBVA"), cents(5_000, 300_000), category_id: category.id, payee: "Nómina Empresa SA")
    end

    def adjustment_row
      account = @accounts.values.sample(random: @random)
      amount = cents(100, 5_000) * (@random.rand < 0.5 ? -1 : 1)
      movement(account, amount, adjustment: true, notes: "Ajuste al cuadrar")
    end

    # Pagos de tarjeta, ahorro, cajero y cuota del préstamo
    def transfer_rows(count)
      routes = [
        [ "Corriente BBVA", "Visa" ], [ "Corriente BBVA", "Mastercard" ], [ "Corriente BBVA", "Ahorro" ],
        [ "Corriente BBVA", "Efectivo" ], [ "Corriente Sabadell", "Préstamo coche" ], [ "Ahorro", "Fondo indexado" ],
        [ "Corriente Sabadell", "Corriente BBVA" ]
      ]
      return [] if count.zero?

      transfer_ids = Transfer.insert_all!(Array.new(count) { { household_id: @household.id } }, returning: :id).rows.flatten
      transfer_ids.flat_map do |transfer_id|
        from, to = routes.sample(random: @random)
        amount = cents(2_000, 80_000)
        date = random_date
        status = status_for(date)
        [
          movement(@accounts.fetch(from), -amount, transfer_id: transfer_id, date: date, status: status),
          movement(@accounts.fetch(to), amount, transfer_id: transfer_id, date: date, status: status)
        ]
      end
    end

    def movement(account, amount_cents, date: random_date, status: nil, **attributes)
      { household_id: @household.id, account_id: account.id, currency: account.currency, amount_cents: amount_cents,
        date: date, status: status || status_for(date), category_id: nil, payee: nil, notes: nil,
        transfer_id: nil, adjustment: false }.merge(attributes)
    end

    # El último 1 % del rango cae en el futuro (programado); lo de los últimos días, a veces pendiente
    def random_date
      span = (today - start_date).to_i
      start_date + @random.rand(span + (span / 100))
    end

    def status_for(date)
      if date > today
        "scheduled"
      elsif date > today - 5 && @random.rand < 0.5
        "pending"
      else
        "cleared"
      end
    end

    def cents(min, max)
      @random.rand(min..max)
    end

    def weighted(weights)
      pick = @random.rand(weights.values.sum)
      weights.each { |key, weight| return key if (pick -= weight).negative? }
    end

    def expense_categories
      @expense_categories ||= categories.select(&:expense?)
    end

    def income_categories
      @income_categories ||= categories.select(&:income?)
    end

    def categories
      @categories ||= Category.where(household_id: @household.id).order(:id).to_a
    end
end
