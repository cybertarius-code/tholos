# Transferencia entre dos cuentas propias (ADR-0004): dos movimientos, uno de
# salida y otro de entrada, que apuntan aquí con transactions.transfer_id. No
# llevan categoría y no cuentan como ingreso ni gasto (ADR-0014); el pago de la
# tarjeta de crédito es una transferencia corriente → tarjeta.
#
# La BD garantiza como mucho una salida y una entrada (transactions_un_lado_por_signo)
# y que un lado no lleve categoría (transactions_un_solo_tipo). El resto del
# invariante vive aquí: exactamente dos lados, importes opuestos, misma fecha,
# misma moneda, mismo hogar y cuentas distintas y abiertas. Crear, editar y
# borrar ocurren en una única transacción de BD.
#
# El formulario trabaja con atributos virtuales (cuentas, importe, fecha y
# notas); antes de validar se copian a los dos lados.
class Transfer < ApplicationRecord
  belongs_to :household
  has_many :legs, class_name: "Transaction", inverse_of: :transfer,
    autosave: true, validate: false, dependent: :destroy

  attr_writer :from_account_id, :to_account_id, :date, :notes

  validate :inputs_are_valid
  validate :legs_are_valid

  # Crea la transferencia y sus dos lados, o nada. Lanza RecordInvalid.
  # La usan el formulario y la importación (US-0114).
  def self.record!(household:, from:, to:, amount_cents:, date:, notes: nil)
    transfer = new(household: household, from_account_id: from&.id, to_account_id: to&.id,
                   amount_cents: amount_cents, date: date, notes: notes)
    transfer.save!
    transfer
  end

  # Savepoint: si falla el segundo lado no queda nada, tampoco dentro de una
  # transacción exterior (importación, tests)
  def save(**)
    transaction(requires_new: true) { super }
  rescue ActiveRecord::RecordInvalid
    errors.add(:base, :invalid_legs) if errors.empty?
    false
  end

  def save!(**)
    transaction(requires_new: true) { super }
  end

  def outflow
    legs.detect { |leg| leg.amount_cents.to_i.negative? }
  end

  def inflow
    legs.detect { |leg| leg.amount_cents.to_i.positive? }
  end

  # El otro lado de un movimiento de esta transferencia
  def counterpart_of(leg)
    legs.detect { |other| other.id != leg.id }
  end

  def from_account_id
    (defined?(@from_account_id) ? @from_account_id : outflow&.account_id).presence&.to_i
  end

  def to_account_id
    (defined?(@to_account_id) ? @to_account_id : inflow&.account_id).presence&.to_i
  end

  def date
    value = defined?(@date) ? @date : inflow&.date
    value.is_a?(String) ? Date.iso8601(value) : value
  rescue Date::Error
    nil
  end

  def notes
    defined?(@notes) ? @notes.to_s.strip.presence : inflow&.notes
  end

  # Importe positivo en céntimos; el de salida es su opuesto
  def amount_cents
    return @amount_cents if defined?(@amount_cents)
    return amount_input_cents if defined?(@amount_input)

    inflow&.amount_cents
  end

  def amount_cents=(value)
    remove_instance_variable(:@amount_input) if defined?(@amount_input)
    @amount_cents = value&.to_i
  end

  def amount
    Money.new(amount_cents, currency) if amount_cents
  end

  # Importe del formulario, en positivo y con coma decimal
  def amount_input
    return @amount_input if defined?(@amount_input)
    return if amount_cents.nil?

    format("%.#{subunit_digits}f", amount_cents.to_d / subunit_to_unit).tr(".", ",")
  end

  def amount_input=(value)
    remove_instance_variable(:@amount_cents) if defined?(@amount_cents)
    @amount_input = value.to_s.strip
  end

  def from_account
    account_record(from_account_id)
  end

  def to_account
    account_record(to_account_id)
  end

  def currency
    from_account&.currency || inflow&.currency
  end

  private
    # Sin pasar por asociaciones: con strict_loading no se cargan perezosamente
    def account_record(id)
      return if id.nil?

      @account_records ||= {}
      @account_records[id] ||= Account.find_by(id: id, household_id: household_id)
    end

    def amount_input_cents
      amount = Transaction.parse_amount_input(@amount_input)
      return if amount.nil?

      (amount.abs * subunit_to_unit).round(0, BigDecimal::ROUND_HALF_UP).to_i
    end

    def inputs_are_valid
      validate_amount
      validate_account(:from_account_id, from_account, outflow&.account_id)
      validate_account(:to_account_id, to_account, inflow&.account_id)
      errors.add(:date, :blank) if date.nil?
      return if errors.include?(:from_account_id) || errors.include?(:to_account_id)

      if from_account_id == to_account_id
        errors.add(:to_account_id, :same_as_from)
      elsif from_account.currency != to_account.currency
        errors.add(:to_account_id, :currency_mismatch)
      end
    end

    def validate_amount
      if defined?(@amount_input) && Transaction.parse_amount_input(@amount_input).nil?
        errors.add(:amount, @amount_input.blank? ? :blank : :not_a_number)
      elsif !amount_cents.to_i.positive?
        errors.add(:amount, :must_be_positive)
      end
    end

    # Una cuenta cerrada solo se rechaza al crear o al cambiar a ella, igual que
    # en Transaction: editar la nota de una transferencia antigua sigue pudiéndose
    def validate_account(attribute, account, current_id)
      if account.nil?
        errors.add(attribute, public_send(attribute).nil? ? :blank : :invalid)
      elsif account.closed? && account.id != current_id
        errors.add(attribute, :closed)
      end
    end

    # Copia los datos del formulario a los dos lados y comprueba el invariante.
    # Solo si los datos son válidos, para no repetir los mismos errores.
    def legs_are_valid
      return if errors.any?

      sync_legs
      if legs.size != 2 || outflow.nil? || inflow.nil?
        errors.add(:base, :two_legs)
      elsif outflow.amount_cents != -inflow.amount_cents || outflow.date != inflow.date ||
          outflow.currency != inflow.currency || outflow.household_id != inflow.household_id
        errors.add(:base, :unbalanced)
      end

      legs.each do |leg|
        next if leg.valid?

        leg.errors.each { |error| errors.add(:base, error.full_message) unless errors.added?(:base, error.full_message) }
      end
    end

    def sync_legs
      out_leg = outflow || legs.build
      in_leg = inflow || legs.build
      cents = amount_cents.to_i

      { out_leg => [ from_account, -cents ], in_leg => [ to_account, cents ] }.each do |leg, (account, signed_cents)|
        leg.assign_attributes(household_id: household_id, account_id: account.id, currency: account.currency,
                              amount_cents: signed_cents, date: date, notes: notes, category_id: nil, payee: nil)
      end
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
