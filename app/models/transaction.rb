# Un movimiento del libro mayor (ADR-0004): importe con signo en la moneda de
# su cuenta. Es transferencia, ajuste o ingreso/gasto, nunca dos a la vez
# (ADR-0014 A). El tipo de ingreso/gasto lo da su categoría, no el signo: una
# devolución es un importe positivo en una categoría de gasto.
#
# Convive con ActiveRecord::Transaction sin chocar (comprobado en TSK-US-0104 §0).
class Transaction < ApplicationRecord
  include ConstraintViolationErrors

  STATUSES = %w[ scheduled pending cleared ].freeze
  DIRECTIONS = %w[ expense income ].freeze

  belongs_to :household
  belongs_to :account
  belongs_to :category, optional: true
  belongs_to :transfer, optional: true, inverse_of: :legs

  enum :status, STATUSES.index_with(&:itself), default: :cleared, validate: true

  monetize :amount_cents, with_model_currency: :currency

  constraint_error "transactions_importe_no_cero", :amount, :cannot_be_zero
  constraint_error "transactions_un_solo_tipo", :base, :un_solo_tipo
  constraint_error "transactions_account_household_fk", :account_id, :invalid
  constraint_error "transactions_account_currency_fk", :currency, :mismatch
  constraint_error "transactions_category_household_fk", :category_id, :invalid

  normalizes :payee, with: ->(payee) { payee.squish.presence }
  normalizes :notes, with: ->(notes) { notes.strip.presence }

  validates :date, presence: true
  validates :payee, length: { maximum: 120 }
  validate :amount_is_valid
  validate :account_is_valid
  validate :category_is_valid, if: :category_id?
  validate :one_kind_only

  before_validation :copy_currency_from_account, on: :create
  before_validation :apply_amount_input
  after_save :forget_amount_input

  scope :cleared, -> { where(status: "cleared") }
  scope :on_or_before, ->(date) { where(date: ..date) }
  scope :income_and_expense, -> { where(transfer_id: nil, adjustment: false) }
  scope :recent_first, -> { order(date: :desc, id: :desc) }

  # Importe escrito en positivo: "12,50" y "1.234,56" (es), "12.50"; un punto
  # seguido de 3 cifras es de miles. Devuelve un BigDecimal o nil.
  def self.parse_amount_input(value)
    text = value.to_s.delete(" ")
    return if text.blank?

    if text.include?(",")
      text = text.delete(".").tr(",", ".")
    elsif text.match?(/\.\d{3}\z/) || text.count(".") > 1
      text = text.delete(".")
    end
    BigDecimal(text, exception: false)
  end

  def transfer?
    transfer_id.present?
  end

  # Un lado de una transferencia no se borra solo: borra la transferencia
  # entera, con sus dos lados, en una transacción (ADR-0004)
  def destroy
    return super if !transfer? || destroyed_by_association

    transfer = Transfer.includes(:legs).find(transfer_id)
    return false unless transfer.destroy

    @destroyed = true
    freeze
  end

  # Pestaña del formulario: el signo del importe
  def direction
    @direction || (amount_cents.to_i.positive? ? "income" : "expense")
  end

  def direction=(value)
    @direction = value.to_s.presence_in(DIRECTIONS)
  end

  # Importe del formulario, siempre en positivo; admite coma decimal ("12,50", "1.234,56")
  def amount_input
    return @amount_input if defined?(@amount_input)
    return if amount_cents.nil?

    format("%.#{subunit_digits}f", amount_cents.abs.to_d / subunit_to_unit).tr(".", ",")
  end

  def amount_input=(value)
    @amount_input = value.to_s.strip
  end

  private
    # Sin pasar por las asociaciones: con strict_loading no se cargan perezosamente
    def account_record
      return if account_id.nil?
      return account if association(:account).loaded? && account&.id == account_id

      @account_record = nil unless @account_record&.id == account_id
      @account_record ||= Account.find_by(id: account_id)
    end

    def category_record
      return if category_id.nil?
      return category if association(:category).loaded? && category&.id == category_id

      @category_record = nil unless @category_record&.id == category_id
      @category_record ||= Category.find_by(id: category_id)
    end

    def copy_currency_from_account
      self.currency = account_record.currency if account_record
    end

    def apply_amount_input
      return unless defined?(@amount_input)
      return unless (amount = parsed_amount_input)

      cents = (amount.abs * subunit_to_unit).round(0, BigDecimal::ROUND_HALF_UP).to_i
      self.amount_cents = direction == "income" ? cents : -cents
    end

    def forget_amount_input
      remove_instance_variable(:@amount_input) if defined?(@amount_input)
      @direction = nil
    end

    def parsed_amount_input
      self.class.parse_amount_input(@amount_input)
    end

    def amount_is_valid
      if defined?(@amount_input) && parsed_amount_input.nil?
        errors.add(:amount, @amount_input.blank? ? :blank : :not_a_number)
      elsif amount_cents.to_i.zero?
        errors.add(:amount, :cannot_be_zero)
      end
    end

    def account_is_valid
      candidate = account_record
      if candidate.nil? || candidate.household_id != household_id
        errors.add(:account_id, :invalid)
      elsif candidate.closed? && (new_record? || account_id_changed?)
        errors.add(:account_id, :closed)
      elsif candidate.currency != currency
        errors.add(:currency, :mismatch)
      end
    end

    def category_is_valid
      candidate = category_record
      if candidate.nil? || candidate.household_id != household_id
        errors.add(:category_id, :invalid)
      elsif candidate.archived? && (new_record? || category_id_changed?)
        errors.add(:category_id, :archived)
      end
    end

    # ADR-0014 A: misma regla que el CHECK transactions_un_solo_tipo
    def one_kind_only
      kinds = [ transfer_id, (true if adjustment?), category_id ].compact
      errors.add(:base, :un_solo_tipo) if kinds.size > 1
    end

    def money_currency
      Money::Currency.find(currency.to_s) || Money.default_currency
    end

    def subunit_to_unit
      money_currency.subunit_to_unit
    end

    def subunit_digits
      Math.log10(subunit_to_unit).round
    end
end
