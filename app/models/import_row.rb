# Una fila de un extracto cargado (US-0113). Se corrige en sitio (fecha,
# importe y concepto) y se decide: omitir, una categoría de gasto o ingreso,
# una transferencia a/desde otra cuenta del hogar (US-0114) o "ya registrado",
# que enlaza la fila con un movimiento que ya existe sin crear otro.
# Su huella (import_ref) se calcula al cargar y no cambia al corregirla.
class ImportRow < ApplicationRecord
  include ConstraintViolationErrors

  belongs_to :import
  belongs_to :category, optional: true
  belongs_to :counter_account, class_name: "Account", optional: true
  belongs_to :matched_transaction, class_name: "Transaction", optional: true

  # Margen de fechas para "ya registrado"
  MATCH_WINDOW = 7

  # duplicate: su huella ya está en un movimiento; before_cutoff: fecha igual o
  # anterior al saldo inicial de la cuenta. Las dos se omiten y no se pueden cambiar.
  enum :proposal, { none: "none", duplicate: "duplicate", before_cutoff: "before_cutoff" },
    prefix: true, default: :none, validate: true

  constraint_error "import_rows_una_decision", :decision, :invalid

  validates :date, :concept, presence: true
  validate :amount_is_valid
  validate :category_is_valid, if: :category_id_changed?
  validate :counter_account_is_valid, if: :counter_account_id_changed?
  validate :matched_transaction_is_valid, if: -> { matched_transaction_id && (matched_transaction_id_changed? || amount_cents_changed? || date_changed?) }

  scope :undecided, -> { where(skipped: false, category_id: nil, counter_account_id: nil, matched_transaction_id: nil) }

  # Huella: SHA256(cuenta | fecha | importe | concepto normalizado | saldo)
  def self.fingerprint(account_id:, date:, amount_cents:, concept:, balance_cents:)
    Digest::SHA256.hexdigest([ account_id, date.iso8601, amount_cents, concept.to_s.squish.upcase, balance_cents ].join("|"))
  end

  def locked?
    !proposal_none? || import.confirmed?
  end

  def undecided?
    !skipped? && category_id.nil? && counter_account_id.nil? && matched_transaction_id.nil?
  end

  def transfer?
    counter_account_id.present?
  end

  def already_recorded?
    matched_transaction_id.present?
  end

  # Valor del desplegable de decisión: "skip", el id de la categoría,
  # "transfer:<cuenta>", "recorded:<movimiento>" o "" (sin decidir)
  def decision
    if skipped? then "skip"
    elsif transfer? then "transfer:#{counter_account_id}"
    elsif already_recorded? then "recorded:#{matched_transaction_id}"
    else category_id.to_s
    end
  end

  def decision=(value)
    kind, id = value.to_s.split(":", 2)
    self.skipped = kind == "skip"
    self.counter_account_id = (id.presence if kind == "transfer")
    self.matched_transaction_id = (id.presence if kind == "recorded")
    self.category_id = (kind.presence if id.nil? && !skipped?)
  end

  # Importe con signo, con coma decimal ("-2,40")
  def amount_input
    return @amount_input if defined?(@amount_input)
    return if amount_cents.nil?

    format("%.2f", amount_cents.to_d / 100).tr(".", ",")
  end

  def amount_input=(value)
    @amount_input = value.to_s.strip
    amount = Transaction.parse_amount_input(@amount_input)
    self.amount_cents = (amount * 100).round(0, BigDecimal::ROUND_HALF_UP).to_i if amount
  end

  private
    def amount_is_valid
      if defined?(@amount_input) && Transaction.parse_amount_input(@amount_input).nil?
        errors.add(:amount, @amount_input.blank? ? :blank : :not_a_number)
      elsif amount_cents.to_i.zero?
        errors.add(:amount, :cannot_be_zero)
      end
    end

    def category_is_valid
      return if category_id.nil?

      candidate = Category.find_by(id: category_id)
      if candidate.nil? || candidate.household_id != import.household_id
        errors.add(:category_id, :invalid)
      elsif candidate.archived?
        errors.add(:category_id, :archived)
      end
    end

    # Activa, del hogar, de la misma moneda y distinta de la importada
    def counter_account_is_valid
      return if counter_account_id.nil?

      accounts = Account.where(id: [ counter_account_id, import.account_id ], household_id: import.household_id).index_by(&:id)
      candidate = accounts[counter_account_id]
      imported = accounts.fetch(import.account_id)
      if candidate.nil? || candidate.id == imported.id
        errors.add(:counter_account_id, :invalid)
      elsif candidate.closed?
        errors.add(:counter_account_id, :closed)
      elsif candidate.currency != imported.currency
        errors.add(:counter_account_id, :currency_mismatch)
      end
    end

    # De la cuenta importada, mismo importe, sin huella y a ± MATCH_WINDOW días
    def matched_transaction_is_valid
      candidate = Transaction.find_by(id: matched_transaction_id, household_id: import.household_id)
      if candidate.nil? || candidate.account_id != import.account_id || candidate.import_ref.present?
        errors.add(:matched_transaction_id, :invalid)
      elsif candidate.amount_cents != amount_cents || date.nil? || (candidate.date - date).abs > MATCH_WINDOW
        errors.add(:matched_transaction_id, :mismatch)
      end
    end
end
