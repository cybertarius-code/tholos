module Imports
  # Segundo paso de ADR-0017, en una sola transacción; si una fila falla no se
  # crea nada y queda señalada. Por fila:
  # - con categoría: un movimiento, a través de Transaction (sin bulk);
  # - transferencia (US-0114): Transfer.record!; la huella va al lado de la
  #   cuenta importada y el otro lado queda sin huella, para enlazarlo al
  #   importar el extracto de la otra cuenta;
  # - ya registrado (US-0114): no crea nada; el movimiento enlazado recibe la
  #   huella, así que al reimportar el extracto la fila sale duplicada.
  class Commit
    Result = Data.define(:created, :linked, :undecided_lines, :failed_line) do
      def success? = undecided_lines.empty? && failed_line.nil?
    end

    def self.call(...) = new(...).call

    def initialize(import)
      @import = import
    end

    def call
      rows = ImportRow.where(import_id: @import.id).includes(:category).order(:line).to_a
      undecided = rows.select(&:undecided?).map(&:line)
      return Result.new(created: 0, linked: 0, undecided_lines: undecided, failed_line: nil) if undecided.any?

      ImportRow.where(import_id: @import.id).where.not(commit_error: nil).update_all(commit_error: nil)
      created, linked, failed_row, message = apply(rows.reject(&:skipped?))
      failed_row&.update_column(:commit_error, message)

      Result.new(created:, linked:, undecided_lines: [], failed_line: failed_row&.line)
    end

    private
      def apply(rows)
        @account = Account.find(@import.account_id)
        @created = 0
        @linked = 0
        failed = nil

        ActiveRecord::Base.transaction do
          # Dos confirmaciones a la vez: la segunda espera y ve la importación ya confirmada
          @import.lock!
          raise ActiveRecord::Rollback if @import.confirmed?

          rows.each do |row|
            message = apply_row(row)
            next unless message

            failed = [ row, message ]
            raise ActiveRecord::Rollback
          end

          @import.update!(status: :confirmed, confirmed_at: Time.current)
        end

        failed ? [ 0, 0, *failed ] : [ @created, @linked, nil, nil ]
      end

      # Devuelve el motivo si la fila no se puede aplicar
      def apply_row(row)
        if row.transfer? then record_transfer(row)
        elsif row.already_recorded? then link(row)
        else create_movement(row)
        end
      rescue ActiveRecord::RecordInvalid => error
        error.record.errors.full_messages.to_sentence
      rescue ActiveRecord::RecordNotUnique
        I18n.t("imports.commits.errors.already_linked")
      end

      def create_movement(row)
        movement = Transaction.new(household_id: @import.household_id, account: @account, category: row.category,
                                   amount_cents: row.amount_cents, date: row.date, payee: row.concept,
                                   status: :cleared, import_ref: row.import_ref)
        return movement.errors.full_messages.to_sentence unless movement.save

        @created += 1
        nil
      end

      # El signo de la fila da la dirección: negativo, "transferencia a"
      def record_transfer(row)
        counter = Account.find_by(id: row.counter_account_id, household_id: @import.household_id)
        from, to = row.amount_cents.negative? ? [ @account, counter ] : [ counter, @account ]
        transfer = Transfer.record!(household: household, from: from, to: to,
                                    amount_cents: row.amount_cents.abs, date: row.date, notes: row.concept)
        leg = row.amount_cents.negative? ? transfer.outflow : transfer.inflow
        leg.update!(import_ref: row.import_ref)
        @created += 2
        nil
      end

      def household
        @household ||= Household.find(@import.household_id)
      end

      # Solo si sigue sin huella: dos filas no pueden enlazar el mismo movimiento
      def link(row)
        updated = Transaction.where(id: row.matched_transaction_id, account_id: @account.id, import_ref: nil)
          .update_all(import_ref: row.import_ref, updated_at: Time.current)
        return I18n.t("imports.commits.errors.already_linked") if updated.zero?

        @linked += 1
        nil
      end
  end
end
