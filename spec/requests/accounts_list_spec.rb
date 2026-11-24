require "rails_helper"

RSpec.describe "Lista y detalle de cuentas (US-0102)", type: :request do
  let(:user) { create(:user, :with_household) }
  let(:household) { Household.joins(:memberships).find_by!(memberships: { user_id: user.id }) }

  before { sign_in_as(user) }

  def page
    Nokogiri::HTML(response.body)
  end

  def names_in(selector)
    page.css("#{selector} li[id^='account_'] span.font-medium").map { |node| node.text.strip }
  end

  describe "GET /cuentas" do
    it "agrupa en 'Efectivo y bancos' y 'Tarjetas y préstamos'; inversión y otras van con los bancos" do
      create(:account, household: household, name: "Corriente")
      create(:account, household: household, name: "Ahorro", kind: "savings")
      create(:account, household: household, name: "Fondo", kind: "investment")
      create(:account, :credit_card, household: household, name: "Visa")
      create(:account, household: household, name: "Hipoteca", kind: "loan")

      get accounts_path

      expect(page.at_css("#group-cash_and_banks").text).to eq("Efectivo y bancos")
      expect(page.at_css("#group-cards_and_loans").text).to eq("Tarjetas y préstamos")
      expect(names_in("section[aria-labelledby='group-cash_and_banks']")).to contain_exactly("Corriente", "Ahorro", "Fondo")
      expect(names_in("section[aria-labelledby='group-cards_and_loans']")).to contain_exactly("Visa", "Hipoteca")
    end

    it "cada tarjeta muestra el saldo actual en grande y el proyectado en pequeño" do
      account = create(:account, household: household, name: "Corriente", opening_balance_cents: 10_000)
      create(:transaction, account: account, amount_cents: -3_000, date: Date.current - 1)
      create(:transaction, :scheduled, account: account, amount_cents: -2_000, date: Date.current + 1)

      get accounts_path

      card = page.at_css("##{ActionView::RecordIdentifier.dom_id(account)}")
      expect(card.at_css("[data-balance=current]")["class"]).to include("text-2xl")
      expect(card.at_css("[data-balance=current]").text.squish).to eq("70,00 €")
      expect(card.at_css("[data-balance=projected]").text.squish).to eq("Proyectado: 50,00 €")
      expect(card.at_css("a")["href"]).to eq(account_path(account))
    end

    it "una deuda sale en rojo" do
      create(:account, :credit_card, household: household, name: "Visa", opening_balance_cents: -45_000)

      get accounts_path

      expect(page.at_css("[data-balance=current] span")["class"]).to include("text-expense")
    end

    it "las cerradas no están en los grupos, sino en una sección plegada 'Cerradas'" do
      create(:account, household: household, name: "Corriente")
      create(:account, :closed, household: household, name: "Vieja")

      get accounts_path

      expect(names_in("section[aria-labelledby='group-cash_and_banks']")).to eq([ "Corriente" ])
      closed = page.at_css("details#closed-accounts")
      expect(closed["open"]).to be_nil
      expect(closed.at_css("summary").text.squish).to eq("Cerradas (1)")
      expect(names_in("details#closed-accounts")).to eq([ "Vieja" ])
    end

    it "sin cerradas no hay sección 'Cerradas'; sin pasivos no hay grupo de tarjetas" do
      create(:account, household: household, name: "Corriente")

      get accounts_path

      expect(page.at_css("details#closed-accounts")).to be_nil
      expect(page.at_css("#group-cards_and_loans")).to be_nil
    end

    it "totaliza cada grupo por moneda, sin convertir" do
      create(:account, household: household, opening_balance_cents: 100_000)
      create(:account, household: household, opening_balance_cents: 50_000)
      create(:account, household: household, currency: "USD", opening_balance_cents: 20_000)
      create(:account, :closed, household: household, opening_balance_cents: 999_999)

      get accounts_path

      totals = page.css("section[aria-labelledby='group-cash_and_banks'] [data-total]").to_h { |node| [ node["data-total"], node.text.squish ] }
      expect(totals.keys).to eq(%w[ EUR USD ])
      expect(totals["EUR"]).to start_with("1.500,00 €")
      expect(totals["USD"]).to start_with("200,00 $")
    end

    it "hace las mismas consultas con 1 y con 10 cuentas, también con cerradas y tarjetas" do
      count_queries = lambda do
        queries = 0
        callback = ->(*, payload) { queries += 1 unless payload[:name].in?(%w[ SCHEMA TRANSACTION ]) }
        ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { get accounts_path }
        queries
      end
      create(:transaction, account: create(:account, household: household))
      get accounts_path
      one = count_queries.call

      4.times { create(:transaction, account: create(:account, household: household)) }
      3.times { create(:account, :credit_card, household: household) }
      2.times { create(:account, :closed, household: household) }

      expect(household.accounts.count).to eq(10)
      expect(count_queries.call).to eq(one)
    end
  end

  describe "GET /cuentas/:id" do
    let(:account) { create(:account, household: household, name: "Corriente", opening_balance_cents: 10_000) }

    it "muestra saldo actual y proyectado, el gráfico de 90 días con su resumen y tabla, y el enlace a la lista filtrada" do
      create(:transaction, account: account, amount_cents: -3_000, date: Date.current - 1)
      create(:transaction, :scheduled, account: account, amount_cents: -2_000, date: Date.current + 1)

      get account_path(account)

      expect(response.body).to include("70,00 €", "50,00 €")
      chart = page.at_css("[data-controller=balance-chart]")
      series = JSON.parse(chart["data-balance-chart-series-value"])
      expect(series.size).to eq(90)
      expect(series.last).to eq([ Date.current.iso8601, 7_000 ])
      expect(chart.at_css("canvas")["aria-label"]).to include("de 100,00 € a 70,00 €")
      expect(page.css("details table tbody tr").size).to eq(90)
      expect(page.at_css("a[href='#{transactions_path(account_id: account.id)}']")).to be_present
    end

    it "lista los últimos 20 movimientos" do
      create_list(:transaction, 25, account: account, date: Date.current)

      get account_path(account)

      expect(page.css("#account-transactions + * li, section[aria-labelledby=account-transactions] li").size).to eq(20)
    end
  end

  it "la página declara el idioma (Lighthouse: html-has-lang)" do
    get accounts_path

    expect(page.at_css("html")["lang"]).to eq("es")
  end
end
