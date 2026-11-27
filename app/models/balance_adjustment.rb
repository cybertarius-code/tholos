# Formulario "Ajustar saldo" (US-0108): el saldo real que dice el banco en una
# fecha. La diferencia no se calcula aquí sino al guardar, en
# Account#adjust_balance!, por si cambia algo entre medias.
class BalanceAdjustment
  include ActiveModel::Model
  include ActiveModel::Attributes

  attr_accessor :account
  attr_reader :movement

  attribute :amount_input, :string
  attribute :date, :date, default: -> { Date.current }

  validates :date, presence: true
  validate :amount_is_a_number

  # true si se ha guardado, aunque no haga falta movimiento (movement es nil)
  def save
    return false unless valid?

    @movement = account.adjust_balance!(to_cents: to_cents, on: date)
    true
  end

  private
    def parsed_amount
      Transaction.parse_amount_input(amount_input)
    end

    # En tarjetas y préstamos se escribe la deuda en positivo, como el saldo inicial
    def to_cents
      subunit = (Money::Currency.find(account.currency) || Money.default_currency).subunit_to_unit
      cents = (parsed_amount * subunit).round(0, BigDecimal::ROUND_HALF_UP).to_i
      account.liability? ? -cents : cents
    end

    def amount_is_a_number
      errors.add(:amount_input, amount_input.blank? ? :blank : :not_a_number) if parsed_amount.nil?
    end
end
