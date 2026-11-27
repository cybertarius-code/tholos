module Households
  # Vuelca un hogar a un Hash serializable a JSON (KB-0006): categorías,
  # cuentas, transferencias y movimientos, más los datos originales de cada
  # huella de importación para poder recalcularla en otro hogar. No incluye
  # usuarios, sesiones ni las importaciones (solo sus huellas).
  #
  #   File.write(path, JSON.pretty_generate(Households::Dump.call(household)))
  class Dump
    FORMAT = "tholos-household"
    VERSION = 1

    CATEGORY_FIELDS = %w[ id parent_id name kind report_group color icon position archived_at ].freeze
    ACCOUNT_FIELDS = %w[ id name kind currency opening_balance_cents opening_date status include_in_net_worth notes position created_at ].freeze
    TRANSACTION_FIELDS = %w[ id account_id category_id transfer_id amount_cents currency date status payee notes adjustment import_ref created_at ].freeze

    def self.call(household) = new(household).call

    def initialize(household)
      @household = household
    end

    def call
      transactions = rows(Transaction.where(household_id: @household.id).order(:date, :id), TRANSACTION_FIELDS)

      {
        "format" => FORMAT,
        "version" => VERSION,
        "exported_at" => Time.current.iso8601,
        "household" => { "id" => @household.id, "name" => @household.name, "base_currency" => @household.base_currency },
        "categories" => rows(Category.where(household_id: @household.id).order(Arel.sql("parent_id NULLS FIRST"), :id), CATEGORY_FIELDS),
        "accounts" => rows(Account.where(household_id: @household.id).order(:id), ACCOUNT_FIELDS),
        "transactions" => transactions,
        "fingerprints" => fingerprints(transactions.filter_map { |transaction| transaction["import_ref"] })
      }
    end

    private
      def rows(scope, fields)
        scope.pluck(*fields).map { |values| fields.zip(Array(values)).to_h }
      end

      # { huella => { date, amount_cents, concept, balance_cents } } de las filas
      # importadas que la tienen guardada (las cargadas antes y corregidas, no)
      def fingerprints(refs)
        ImportRow.where(import_ref: refs).where.not(original_date: nil)
          .pluck(:import_ref, :original_date, :original_amount_cents, :original_concept, :balance_cents)
          .to_h { |ref, date, amount, concept, balance| [ ref, { "date" => date, "amount_cents" => amount, "concept" => concept, "balance_cents" => balance } ] }
      end
  end
end
