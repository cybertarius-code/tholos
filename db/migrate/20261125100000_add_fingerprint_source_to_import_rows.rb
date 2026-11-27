# Datos originales con los que se calculó la huella de cada fila (import_ref).
# Sin ellos no se puede recalcular la huella al copiar un hogar a otro, porque
# la cuenta cambia de id y la fila puede tener el concepto, la fecha o el
# importe corregidos (KB-0006). El saldo no se corrige: basta balance_cents.
class AddFingerprintSourceToImportRows < ActiveRecord::Migration[8.1]
  class Row < ActiveRecord::Base
    self.table_name = "import_rows"
  end

  def up
    add_column :import_rows, :original_date, :date
    add_column :import_rows, :original_amount_cents, :bigint
    add_column :import_rows, :original_concept, :string

    # Filas ya cargadas: solo si sus valores actuales aún dan su huella (no se corrigieron)
    account_ids = select_rows("SELECT id, account_id FROM imports").to_h
    Row.reset_column_information
    Row.find_each do |row|
      ref = [ account_ids.fetch(row.import_id), row.date.iso8601, row.amount_cents, row.concept.to_s.squish.upcase, row.balance_cents ].join("|")
      next unless Digest::SHA256.hexdigest(ref) == row.import_ref

      row.update_columns(original_date: row.date, original_amount_cents: row.amount_cents, original_concept: row.concept)
    end
  end

  def down
    remove_column :import_rows, :original_date
    remove_column :import_rows, :original_amount_cents
    remove_column :import_rows, :original_concept
  end
end
