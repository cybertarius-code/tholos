# Una fila de un extracto cargado (US-0113). Se corrige en sitio (fecha,
# importe y concepto) y se decide: omitir o una categoría de gasto o ingreso.
# Su huella (import_ref) se calcula al cargar y no cambia al corregirla.
class ImportRow < ApplicationRecord
  include ConstraintViolationErrors

  belongs_to :import
  belongs_to :category, optional: true

  # duplicate: su huella ya está en un movimiento; before_cutoff: fecha igual o
  # anterior al saldo inicial de la cuenta. Las dos se omiten y no se pueden cambiar.
  enum :proposal, { none: "none", duplicate: "duplicate", before_cutoff: "before_cutoff" },
    prefix: true, default: :none, validate: true

  constraint_error "import_rows_skipped_sin_categoria", :decision, :invalid

  validates :date, :concept, presence: true
  validate :amount_is_valid
  validate :category_is_valid, if: :category_id_changed?

  scope :undecided, -> { where(skipped: false, category_id: nil) }
  scope :to_commit, -> { where(skipped: false).where.not(category_id: nil) }

  # Huella: SHA256(cuenta | fecha | importe | concepto normalizado | saldo)
  def self.fingerprint(account_id:, date:, amount_cents:, concept:, balance_cents:)
    Digest::SHA256.hexdigest([ account_id, date.iso8601, amount_cents, concept.to_s.squish.upcase, balance_cents ].join("|"))
  end

  def locked?
    !proposal_none? || import.confirmed?
  end

  def undecided?
    !skipped? && category_id.nil?
  end

  # Valor del desplegable de decisión: "skip", el id de la categoría o "" (sin decidir)
  def decision
    skipped? ? "skip" : category_id.to_s
  end

  def decision=(value)
    self.skipped = value == "skip"
    self.category_id = skipped? ? nil : value.presence
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
end
