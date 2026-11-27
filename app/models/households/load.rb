module Households
  # Carga un volcado de Households::Dump en otro hogar (KB-0006), todo o nada.
  # El hogar de destino no puede tener cuentas. Sus categorías se reutilizan
  # si coinciden en tipo, padre y nombre; las que faltan se crean.
  #
  # Los ids cambian, así que cada huella de importación se recalcula con la
  # cuenta nueva y los datos originales del volcado: al volver a subir un
  # extracto ya importado, sus filas siguen saliendo como duplicadas. Una
  # huella sin datos originales se pierde (import_ref nil) y se cuenta.
  #
  # Se crea todo a través de los modelos (validaciones y Transfer.record!).
  # Cuentas y categorías se crean abiertas/activas y se cierran/archivan al
  # final, porque un movimiento nuevo no admite una cuenta cerrada ni una
  # categoría archivada.
  class Load
    Result = Data.define(:categories, :accounts, :transactions, :fingerprints_lost)

    def self.call(...) = new(...).call

    def initialize(household, dump)
      @household = household
      @dump = dump
      @categories = {}
      @accounts = {}
      @lost = 0
    end

    def call
      check_dump!
      raise ArgumentError, "El hogar #{@household.id} ya tiene cuentas: la carga es solo para un hogar vacío" if Account.exists?(household_id: @household.id)

      created_categories = 0
      ActiveRecord::Base.transaction do
        created_categories = load_categories
        load_accounts
        load_transactions
        finish
      end

      Result.new(categories: created_categories, accounts: @accounts.size,
                 transactions: @dump["transactions"].size, fingerprints_lost: @lost)
    end

    private
      def check_dump!
        return if @dump["format"] == Dump::FORMAT && @dump["version"] == Dump::VERSION

        raise ArgumentError, "No es un volcado de hogar de Tholos (formato #{@dump['format'].inspect}, versión #{@dump['version'].inspect})"
      end

      # Raíces primero (el volcado va ordenado con parent_id NULLS FIRST)
      def load_categories
        existing = Category.where(household_id: @household.id).to_a
        @dump["categories"].count do |source|
          parent_id = source["parent_id"] && @categories.fetch(source["parent_id"]).id
          match = existing.find do |category|
            category.kind == source["kind"] && category.parent_id == parent_id && category.name.casecmp?(source["name"])
          end
          @categories[source["id"]] = match || Category.create!(
            household: @household, parent_id: parent_id, archived_at: nil,
            **source.slice("name", "kind", "report_group", "color", "icon").symbolize_keys
          )
          match.nil?
        end
      end

      def load_accounts
        @dump["accounts"].each do |source|
          attributes = source.except("id", "status").merge("household_id" => @household.id, "status" => "open")
          @accounts[source["id"]] = Account.create!(attributes)
        end
      end

      def load_transactions
        legs, singles = @dump["transactions"].partition { |source| source["transfer_id"] }
        singles.each { |source| create_movement(source) }
        legs.group_by { |source| source["transfer_id"] }.each_value { |pair| create_transfer(pair) }
      end

      def create_movement(source)
        account = @accounts.fetch(source["account_id"])
        Transaction.create!(
          household_id: @household.id, account: account,
          category: source["category_id"] && @categories.fetch(source["category_id"]),
          import_ref: import_ref(source, account),
          **source.slice("amount_cents", "date", "status", "payee", "notes", "adjustment", "created_at").symbolize_keys
        )
      end

      def create_transfer(pair)
        outflow = pair.find { |leg| leg["amount_cents"].negative? }
        inflow = pair.find { |leg| leg["amount_cents"].positive? }
        raise ArgumentError, "Transferencia #{pair.first['transfer_id']} incompleta en el volcado" unless outflow && inflow && pair.size == 2

        transfer = Transfer.record!(household: @household, from: @accounts.fetch(outflow["account_id"]), to: @accounts.fetch(inflow["account_id"]),
                                    amount_cents: inflow["amount_cents"], date: Date.parse(inflow["date"].to_s), notes: inflow["notes"])
        [ [ transfer.outflow, outflow ], [ transfer.inflow, inflow ] ].each do |leg, source|
          leg.update_columns(import_ref: import_ref(source, leg.account), status: source["status"], created_at: source["created_at"])
        end
      end

      def import_ref(source, account)
        return if source["import_ref"].nil?

        fingerprint = @dump["fingerprints"][source["import_ref"]]
        unless fingerprint
          @lost += 1
          return
        end

        ImportRow.fingerprint(account_id: account.id, **fingerprint.symbolize_keys.merge(date: Date.parse(fingerprint["date"].to_s)))
      end

      def finish
        @dump["accounts"].each { |source| @accounts.fetch(source["id"]).update!(status: source["status"]) }
        @dump["categories"].each do |source|
          category = @categories.fetch(source["id"])
          category.update!(archived_at: source["archived_at"]) if source["archived_at"] && category.archived_at.nil?
        end
      end
  end
end
