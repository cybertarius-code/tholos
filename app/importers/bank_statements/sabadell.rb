module BankStatements
  # Extracto de Sabadell (SPK-0008 §1): .txt separado por "|", en Windows-1252 y
  # sin fila de títulos. Siete campos: fecha de operación, concepto, fecha
  # valor, importe con signo y punto decimal, saldo y dos referencias.
  class Sabadell < CsvImporter::Base
    HEADERS = %w[ fecha concepto fecha_valor importe saldo referencia_1 referencia_2 ].freeze
    TO_CENTS = ->(value) { (value * 100).round.to_i }

    model ImportRow
    csv col_sep: "|", encoding: "Windows-1252:UTF-8", headers: HEADERS

    # La fecha del movimiento es la de operación
    column :date, header: "fecha", required: true, transform: ->(value) { Date.strptime(value, "%d/%m/%Y") }
    column :concept, header: "concepto", required: true
    column :amount_cents, header: "importe", type: :decimal, required: true, transform: TO_CENTS
    column :balance_cents, header: "saldo", type: :decimal, required: true, transform: TO_CENTS
  end
end
