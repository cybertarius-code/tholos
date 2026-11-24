require "rails_helper"

# Presupuesto de US-0112: menos de 15 consultas por página, con datos del seed
# de rendimiento. El número no depende del volumen si no hay N+1; el p95 con
# 10 000 movimientos lo mide bin/perf.
RSpec.describe "Número de consultas (US-0112)", type: :request do
  MAX_QUERIES = 15

  let(:today) { Date.new(2026, 11, 24) }
  let(:household) { Household.find_by!(name: "Rendimiento") }
  let(:account) { Account.find_by!(household_id: household.id, name: "Corriente BBVA") }
  let(:food) { Category.find_by!(household_id: household.id, name: "Alimentación", parent_id: nil) }

  around { |example| travel_to(today) { example.run } }

  before do
    PerformanceSeed.new(total: 1_500, today: today, password: "password1234").call
    sign_in_as(User.find_by!(email_address: "perf@tholos.local"))
  end

  def queries_for(path)
    queries = []
    callback = lambda do |*, payload|
      queries << payload[:sql] unless payload[:name].in?([ "SCHEMA", "TRANSACTION" ]) || payload[:cached]
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { get path }
    expect(response).to have_http_status(:ok)
    queries
  end

  {
    "Movimientos" => ->(_) { transactions_path },
    "Movimientos con una cuenta (saldo acumulado)" => ->(spec) { transactions_path(account_id: spec.account.id) },
    "Movimientos con cuenta, categoría, estado y texto" =>
      ->(spec) { transactions_path(account_id: spec.account.id, category_id: spec.food.id, status: "cleared", q: "mercadona") },
    "Movimientos de un mes con transferencias, página 2" => ->(_) { transactions_path(month: "2026-10", page: 2) },
    "Cuentas" => ->(_) { accounts_path },
    "Detalle de una cuenta" => ->(spec) { account_path(spec.account) }
  }.each do |page, path|
    it "#{page}: menos de #{MAX_QUERIES} consultas" do
      queries = queries_for(instance_exec(self, &path))

      expect(queries.size).to be < MAX_QUERIES, "#{queries.size} consultas:\n#{queries.join("\n")}"
    end
  end
end
