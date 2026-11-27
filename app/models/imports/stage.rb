module Imports
  # Primer paso de ADR-0017: lee el extracto en la propia petición (no se
  # guarda) y carga sus filas en una importación nueva. Todo o nada: con un
  # solo error no queda nada y se devuelven todos, con su línea.
  #
  #   result = Imports::Stage.call(account: account, file: params[:file])
  #   result.import   # la importación, si ha ido bien
  #   result.errors   # [{ line: 3, message: "importe: ..." }]
  #   result.problem  # :missing_file, :too_big o :wrong_format: no se ha leído nada
  class Stage
    MAX_BYTES = 5.megabytes
    FIELDS = BankStatements::Sabadell::HEADERS.size

    Result = Data.define(:import, :errors, :problem) do
      def success? = import.present?
    end

    def self.call(...) = new(...).call

    def initialize(account:, file:)
      @account = account
      @file = file
      @line = 0
    end

    def call
      return failure(problem: :missing_file) unless @file.respond_to?(:path)
      return failure(problem: :too_big) if @file.size > MAX_BYTES
      return failure(problem: :wrong_format) unless sabadell_format?

      import = result = nil
      ActiveRecord::Base.transaction do
        import = Import.create!(household_id: @account.household_id, account: @account, filename: @file.original_filename)
        result = BankStatements::Sabadell.new(@file.path, atomic: true, defaults: { import_id: import.id },
                                              after_map: method(:complete_row)).call
        raise ActiveRecord::Rollback unless result.success?

        mark_proposals(import)
      end

      result.success? ? Result.new(import:, errors: [], problem: nil) : failure(errors: result.errors)
    rescue CsvImporter::InvalidFileError, CsvImporter::InvalidHeaderError
      failure(problem: :wrong_format)
    end

    private
      def failure(errors: [], problem: nil)
        Result.new(import: nil, errors:, problem:)
      end

      # Comprobación previa, para dar un aviso claro en vez de un error por línea:
      # la primera línea tiene los siete campos separados por "|", y el fichero
      # no es UTF-8 (un Windows-1252 con tildes casi nunca es UTF-8 válido).
      def sabadell_format?
        raw = File.binread(@file.path)
        return false if !raw.ascii_only? && raw.dup.force_encoding(Encoding::UTF_8).valid_encoding?

        raw.lines.first.to_s.chomp.split("|", -1).size >= FIELDS
      end

      # after_map: línea (en modo atómico, si se guarda es que no ha fallado
      # ninguna, así que el contador coincide) y huella con el concepto original
      def complete_row(attributes, _raw_row)
        attributes[:line] = (@line += 1)
        attributes[:import_ref] = ImportRow.fingerprint(account_id: @account.id, **attributes.slice(:date, :amount_cents, :concept, :balance_cents))
      end

      def mark_proposals(import)
        rows = ImportRow.where(import_id: import.id)
        rows.where(date: ..@account.opening_date).update_all(proposal: "before_cutoff", skipped: true)
        rows.proposal_none.where(import_ref: Transaction.where.not(import_ref: nil).select(:import_ref))
          .update_all(proposal: "duplicate", skipped: true)
      end
  end
end
