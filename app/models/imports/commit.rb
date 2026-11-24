module Imports
  # Segundo paso de ADR-0017: crea un movimiento por cada fila con categoría, a
  # través de Transaction (validaciones, CHECK y ADR-0014 A; sin bulk), en una
  # sola transacción. Si una fila falla no se crea nada y queda señalada.
  class Commit
    Result = Data.define(:created, :undecided_lines, :failed_line) do
      def success? = undecided_lines.empty? && failed_line.nil?
    end

    def self.call(...) = new(...).call

    def initialize(import)
      @import = import
    end

    def call
      rows = ImportRow.where(import_id: @import.id).includes(:category).order(:line).to_a
      undecided = rows.select(&:undecided?).map(&:line)
      return Result.new(created: 0, undecided_lines: undecided, failed_line: nil) if undecided.any?

      ImportRow.where(import_id: @import.id).where.not(commit_error: nil).update_all(commit_error: nil)
      created, failed_row, message = create_movements(rows.reject(&:skipped?))
      failed_row&.update_column(:commit_error, message)

      Result.new(created:, undecided_lines: [], failed_line: failed_row&.line)
    end

    private
      def create_movements(rows)
        account = Account.find(@import.account_id)
        created = 0
        failed = nil

        ActiveRecord::Base.transaction do
          # Dos confirmaciones a la vez: la segunda espera y ve la importación ya confirmada
          @import.lock!
          raise ActiveRecord::Rollback if @import.confirmed?

          rows.each do |row|
            movement = Transaction.new(household_id: @import.household_id, account: account, category: row.category,
                                       amount_cents: row.amount_cents, date: row.date, payee: row.concept,
                                       status: :cleared, import_ref: row.import_ref)
            if movement.save
              created += 1
            else
              failed = [ row, movement.errors.full_messages.to_sentence ]
              raise ActiveRecord::Rollback
            end
          end

          @import.update!(status: :confirmed, confirmed_at: Time.current)
        end

        failed ? [ 0, *failed ] : [ created, nil, nil ]
      end
  end
end
