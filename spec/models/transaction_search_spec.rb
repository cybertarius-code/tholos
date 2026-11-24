require "rails_helper"

RSpec.describe TransactionSearch do
  let(:household) { create(:household) }
  let(:checking) { create(:account, household: household, name: "Corriente BBVA", opening_balance_cents: 100_000) }
  let(:savings) { create(:account, household: household, name: "Ahorro") }
  let(:food) { create(:category, household: household, name: "Alimentación") }
  let(:supermarket) { create(:category, :child, household: household, parent: food, name: "Supermercado") }
  let(:transport) { create(:category, household: household, name: "Transporte") }

  def search(**attributes)
    described_class.new(household: household, month: "2026-11", **attributes)
  end

  def movement(date, amount_cents = -1_000, account: checking, **attributes)
    create(:transaction, account: account, date: Date.parse(date), amount_cents: amount_cents, **attributes)
  end

  describe "mes" do
    it "por defecto es el mes actual y descarta valores mal formados" do
      travel_to Date.new(2026, 11, 23) do
        expect(described_class.new(household: household).month).to eq("2026-11")
        expect(described_class.new(household: household, month: "2026-13").month).to eq("2026-11")
        expect(described_class.new(household: household, month: "x").month).to eq("2026-11")
      end
    end

    it "solo da los movimientos del mes, del más reciente al más antiguo y, el mismo día, el último creado primero" do
      october = movement("2026-10-31")
      first = movement("2026-11-01")
      same_day_a = movement("2026-11-20")
      same_day_b = movement("2026-11-20")
      december = movement("2026-12-01")

      expect(search.results.to_a).to eq([ same_day_b, same_day_a, first ])
      expect(search.results).not_to include(october, december)
    end

    it "no da movimientos de otro hogar" do
      movement("2026-11-10")
      create(:transaction, date: Date.new(2026, 11, 10))

      expect(search.results.map(&:household_id).uniq).to eq([ household.id ])
    end
  end

  describe "filtros" do
    it "por cuenta" do
      mine = movement("2026-11-10")
      movement("2026-11-10", account: savings)

      expect(search(account_id: checking.id).results).to eq([ mine ])
    end

    it "por categoría padre incluye sus hijas; por hija, solo la hija" do
      parent = movement("2026-11-10", category: food)
      child = movement("2026-11-11", category: supermarket)
      movement("2026-11-12", category: transport)

      expect(search(category_id: food.id).results).to contain_exactly(parent, child)
      expect(search(category_id: supermarket.id).results).to eq([ child ])
    end

    it "por estado" do
      pending = movement("2026-11-10", status: "pending")
      movement("2026-11-11")

      expect(search(status: "pending").results).to eq([ pending ])
      expect(search(status: "nonsense").status).to be_nil
    end

    it "por texto en beneficiario o notas, sin distinguir mayúsculas" do
      by_payee = movement("2026-11-10", payee: "MERCADONA Avda.")
      by_notes = movement("2026-11-11", notes: "compra en mercadona")
      movement("2026-11-12", payee: "Carrefour")

      expect(search(q: "  mercadona ").results).to contain_exactly(by_payee, by_notes)
    end

    it "el texto se busca literal: % y _ no son comodines" do
      literal = movement("2026-11-10", payee: "Rebaja 50% Zara")
      movement("2026-11-11", payee: "Rebaja 500 Zara")

      expect(search(q: "50%").results).to eq([ literal ])
    end

    it "combina cuenta, categoría y texto" do
      match = movement("2026-11-10", category: supermarket, payee: "Mercadona")
      movement("2026-11-10", account: savings, category: supermarket, payee: "Mercadona")
      movement("2026-11-10", category: transport, payee: "Mercadona")
      movement("2026-11-10", category: food, payee: "Lidl")

      expect(search(account_id: checking.id, category_id: food.id, q: "mercadona").results).to eq([ match ])
    end

    it "una cuenta o categoría de otro hogar no da resultados" do
      movement("2026-11-10", category: food)

      expect(search(account_id: create(:account).id).results).to be_empty
      expect(search(category_id: create(:category).id).results).to be_empty
    end

    it "to_params solo lleva los filtros que valen" do
      expect(search(account_id: checking.id, q: " ", status: "x").to_params).to eq(month: "2026-11", account_id: checking.id)
    end
  end

  describe "saldo acumulado" do
    def balances(scope)
      scope.to_a.to_h { |transaction| [ transaction.id, transaction.running_balance_cents ] }
    end

    it "no existe sin una cuenta filtrada" do
      movement("2026-11-10")

      expect(search.running_balance?).to be(false)
      expect(search.results.first).not_to have_attribute(:running_balance_cents)
    end

    it "parte del saldo inicial, suma el histórico de meses anteriores y ordena el mismo día por id" do
      movement("2026-10-15", -10_000)
      a = movement("2026-11-05", -2_000)
      b = movement("2026-11-05", 5_000)
      c = movement("2026-11-07", -500)

      expect(balances(search(account_id: checking.id).results))
        .to eq(c.id => 92_500, b.id => 93_000, a.id => 88_000)
    end

    it "incluye transferencias y ajustes, pero no lo pendiente ni lo programado" do
      transfer = Transfer.record!(household: household, from: checking, to: savings, amount_cents: 30_000, date: Date.new(2026, 11, 3))
      adjustment = movement("2026-11-04", 1_500, adjustment: true)
      pending = movement("2026-11-05", -9_999, status: "pending")
      scheduled = movement("2026-11-06", -8_888, status: "scheduled")
      last = movement("2026-11-07", -500)

      results = balances(search(account_id: checking.id).results)

      expect(results[transfer.outflow.id]).to eq(70_000)
      expect(results[adjustment.id]).to eq(71_500)
      expect(results[pending.id]).to eq(71_500)
      expect(results[scheduled.id]).to eq(71_500)
      expect(results[last.id]).to eq(71_000)
    end

    it "no cambia al paginar ni al filtrar: se calcula antes, sobre todo el histórico" do
      movements = (1..7).map { |day| movement("2026-11-%02d" % day, -1_000) }
      expected = movements.each_with_index.to_h { |transaction, index| [ transaction.id, 100_000 - 1_000 * (index + 1) ] }
      results = search(account_id: checking.id).results

      pages = [ results.limit(3).offset(0), results.limit(3).offset(3), results.limit(3).offset(6) ]

      expect(pages.map(&:size)).to eq([ 3, 3, 1 ])
      expect(pages.map { |page| balances(page) }.reduce(:merge)).to eq(expected)
      expect(balances(search(account_id: checking.id, q: "nada").results)).to be_empty
      expect(results.count).to eq(7)
    end

    it "en el último movimiento conciliado coincide con el saldo actual de la cuenta" do
      travel_to Date.new(2026, 11, 23) do
        movement("2026-11-01", -2_500)
        movement("2026-11-10", 120_000)
        last_cleared = movement("2026-11-20", -3_300)
        movement("2026-11-22", -7_000, status: "pending")

        results = search(account_id: checking.id).results.to_a

        expect(results.find { |transaction| transaction.id == last_cleared.id }.running_balance_cents)
          .to eq(checking.balance_cents)
      end
    end
  end
end
