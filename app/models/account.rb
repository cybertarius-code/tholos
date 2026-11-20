class Account < ApplicationRecord
  include ConstraintViolationErrors

  KINDS = %w[ checking savings cash ewallet credit_card loan investment other ].freeze
  LIABILITY_KINDS = %w[ credit_card loan ].freeze

  belongs_to :household
  has_many :transactions, dependent: :restrict_with_error

  # La BD rechaza cambiar la moneda si hay movimientos (FK compuesta de transactions)
  constraint_error "transactions_account_currency_fk", :currency, :locked

  enum :kind, KINDS.index_with(&:itself), validate: true
  enum :status, { open: "open", closed: "closed" }, default: :open, validate: true

  monetize :opening_balance_cents, with_model_currency: :currency

  normalizes :name, with: ->(name) { name.strip }
  normalizes :currency, with: ->(currency) { currency.strip.upcase }

  validates :name, presence: true, length: { maximum: 100 }
  validates :currency, format: { with: /\A[A-Z]{3}\z/ }
  validate :currency_is_known
  validate :currency_unchanged_with_movements, on: :update
  validates :opening_date, presence: true
  validate :opening_amount_is_a_number

  before_validation :default_currency_from_household, on: :create
  before_validation :apply_opening_amount
  after_save :forget_opening_amount
  before_destroy :ensure_no_movements

  scope :ordered, -> { order(:position, :name) }

  # Activo o pasivo: se deriva del tipo, no se guarda (Glosario)
  def classification
    liability? ? :liability : :asset
  end

  def liability?
    LIABILITY_KINDS.include?(kind)
  end

  # Saldo actual: saldo inicial + movimientos conciliados hasta la fecha (ADR-0005)
  def balance_cents(on: Date.current)
    opening_balance_cents + transactions.cleared.on_or_before(on).sum(:amount_cents)
  end

  # Saldo proyectado: incluye también lo programado y lo pendiente, con cualquier fecha
  def projected_balance_cents
    opening_balance_cents + transactions.sum(:amount_cents)
  end

  # Saldos de varias cuentas en una sola consulta: { account_id => [actual, proyectado] }
  def self.balances_for(accounts, on: Date.current)
    sums = Transaction.where(account_id: accounts.map(&:id)).group(:account_id).pluck(
      :account_id,
      Arel.sql(sanitize_sql_array([ "COALESCE(SUM(amount_cents) FILTER (WHERE status = 'cleared' AND date <= ?), 0)", on ])),
      Arel.sql("SUM(amount_cents)")
    ).to_h { |id, current, projected| [ id, [ current, projected ] ] }

    accounts.to_h do |account|
      current, projected = sums.fetch(account.id, [ 0, 0 ])
      [ account.id, [ account.opening_balance_cents + current, account.opening_balance_cents + projected ] ]
    end
  end

  def movements?
    transactions.exists?
  end

  def close!
    closed!
  end

  def reopen!
    open!
  end

  # Importe que ve el formulario: en tarjetas y préstamos la deuda va en positivo
  def opening_amount
    return @opening_amount if defined?(@opening_amount)

    cents = liability? ? -opening_balance_cents : opening_balance_cents
    format("%.#{subunit_digits}f", cents.to_d / subunit_to_unit)
  end

  def opening_amount=(value)
    @opening_amount = value.to_s.strip
  end

  private
    def default_currency_from_household
      self.currency = household.base_currency if currency.blank? && household
    end

    def parsed_opening_amount
      return BigDecimal(0) if @opening_amount.blank?

      BigDecimal(@opening_amount.tr(",", "."), exception: false)
    end

    def apply_opening_amount
      return unless defined?(@opening_amount)
      return unless (amount = parsed_opening_amount)

      cents = (amount * subunit_to_unit).round(0, BigDecimal::ROUND_HALF_UP).to_i
      self.opening_balance_cents = liability? ? -cents : cents
    end

    def forget_opening_amount
      remove_instance_variable(:@opening_amount) if defined?(@opening_amount)
    end

    def opening_amount_is_a_number
      return unless defined?(@opening_amount)

      errors.add(:opening_amount, :not_a_number) if parsed_opening_amount.nil?
    end

    def currency_is_known
      return if currency.blank? || errors.include?(:currency)

      errors.add(:currency, :invalid) unless Money::Currency.find(currency)
    end

    def currency_unchanged_with_movements
      errors.add(:currency, :locked) if currency_changed? && movements?
    end

    def ensure_no_movements
      return unless movements?

      errors.add(:base, :has_movements)
      throw :abort
    end

    def money_currency
      Money::Currency.find(currency) || Money.default_currency
    end

    def subunit_to_unit
      money_currency.subunit_to_unit
    end

    def subunit_digits
      Math.log10(subunit_to_unit).round
    end
end
