require "rails_helper"

RSpec.describe "GET /movimientos", type: :request do
  let(:user) { create(:user, :with_household) }
  let(:household) { Household.joins(:memberships).find_by!(memberships: { user_id: user.id }) }
  let!(:checking) { create(:account, household: household, name: "Corriente BBVA", opening_balance_cents: 100_000) }
  let!(:savings) { create(:account, household: household, name: "Ahorro") }
  let!(:food) { create(:category, household: household, name: "Alimentación") }
  let!(:supermarket) { create(:category, :child, household: household, parent: food, name: "Supermercado") }
  let!(:transport) { create(:category, household: household, name: "Transporte") }
  let(:today) { Date.new(2026, 11, 23) }

  around { |example| travel_to(today) { example.run } }

  def movement(payee, account: checking, date: today, **attributes)
    create(:transaction, account: account, date: date, payee: payee, **attributes)
  end

  def listed
    Nokogiri::HTML(response.body).css("table tbody tr[id^='transaction_'] td:first-child a:first-child").map { |a| a.text.strip }
  end

  it "sin sesión redirige al login" do
    get transactions_path

    expect(response).to redirect_to(new_session_path)
  end

  context "con sesión" do
    before { sign_in_as(user) }

    it "muestra el mes actual, del más reciente al más antiguo, agrupado por día" do
      movement("Del 2", date: Date.new(2026, 11, 2))
      movement("Del 20", date: Date.new(2026, 11, 20))
      movement("De octubre", date: Date.new(2026, 10, 31))

      get transactions_path

      expect(response).to have_http_status(:ok)
      expect(listed).to eq([ "Del 20", "Del 2" ])
      expect(response.body).to include("Viernes, 20 de noviembre de 2026", "Lunes, 2 de noviembre de 2026")
    end

    it "filtra por mes" do
      movement("De octubre", date: Date.new(2026, 10, 31))
      movement("De noviembre")

      get transactions_path(month: "2026-10")

      expect(listed).to eq([ "De octubre" ])
    end

    it "filtra por cuenta" do
      movement("Corriente")
      movement("Ahorro", account: savings)

      get transactions_path(account_id: checking.id)

      expect(listed).to eq([ "Corriente" ])
    end

    it "filtra por categoría padre con sus hijas" do
      movement("Padre", category: food)
      movement("Hija", category: supermarket)
      movement("Otra", category: transport)

      get transactions_path(category_id: food.id)

      expect(listed).to contain_exactly("Padre", "Hija")
    end

    it "filtra por estado" do
      movement("Pendiente", status: "pending")
      movement("Conciliado")

      get transactions_path(status: "pending")

      expect(listed).to eq([ "Pendiente" ])
    end

    it "filtra por texto en beneficiario o notas" do
      movement("MERCADONA")
      movement("Super", notes: "compra en mercadona")
      movement("Lidl")

      get transactions_path(q: "mercadona")

      expect(listed).to contain_exactly("MERCADONA", "Super")
    end

    it "combina cuenta, categoría y texto, y el formulario conserva los filtros" do
      movement("Mercadona", category: supermarket)
      movement("Mercadona", account: savings, category: supermarket)
      movement("Mercadona", category: transport)

      get transactions_path(account_id: checking.id, category_id: food.id, q: "mercadona")

      expect(listed).to eq([ "Mercadona" ])
      page = Nokogiri::HTML(response.body)
      expect(page.at_css("select[name=account_id] option[selected]")["value"]).to eq(checking.id.to_s)
      expect(page.at_css("select[name=category_id] option[selected]")["value"]).to eq(food.id.to_s)
      expect(page.at_css("input[name=q]")["value"]).to eq("mercadona")
    end

    it "con una cuenta filtrada muestra el saldo después de cada movimiento" do
      movement("Gasto", amount_cents: -2_500, date: Date.new(2026, 11, 1))
      movement("Pendiente", amount_cents: -1_000, status: "pending")

      get transactions_path(account_id: checking.id)

      balances = Nokogiri::HTML(response.body).css("td[data-running-balance]").map { |td| td.text.squish }
      expect(balances).to eq([ "—", "975,00 €" ])
    end

    it "sin cuenta filtrada no muestra la columna de saldo" do
      movement("Gasto")

      get transactions_path

      expect(response.body).not_to include("data-running-balance")
    end

    it "muestra una transferencia con la otra cuenta y enlaza a su edición" do
      transfer = Transfer.record!(household: household, from: checking, to: savings, amount_cents: 30_000, date: today)

      get transactions_path(account_id: checking.id)

      expect(response.body).to include(I18n.t("accounts.show.transfer_to"), %(href="#{edit_transfer_path(transfer)}"))
      expect(response.body).to include(%(href="#{CGI.escapeHTML(transactions_path(account_id: savings.id, month: "2026-11"))}"))
    end

    it "pagina de 50 en 50 y los enlaces conservan los filtros" do
      create_list(:transaction, 55, account: checking, date: today, payee: "Mercadona")
      movement("Otra cuenta", account: savings)

      get transactions_path(account_id: checking.id, q: "mercadona")

      expect(listed.size).to eq(50)
      next_link = Nokogiri::HTML(response.body).at_css("a[rel=next]")["href"]
      expect(Rack::Utils.parse_query(URI(next_link).query))
        .to include("account_id" => checking.id.to_s, "q" => "mercadona", "page" => "2")

      get next_link

      expect(listed.size).to eq(5)
      expect(response.body).to include(I18n.t("transactions.index.page", page: 2, last: 2))
    end

    it "sin resultados muestra el estado vacío" do
      get transactions_path(q: "nada")

      expect(response.body).to include(I18n.t("transactions.index.empty_filtered_title"))
    end

    it "una cuenta o una categoría de otro hogar da 404" do
      get transactions_path(account_id: create(:account).id)
      expect(response).to have_http_status(:not_found)

      get transactions_path(category_id: create(:category).id)
      expect(response).to have_http_status(:not_found)
    end

    it "no muestra movimientos de otro hogar" do
      create(:transaction, date: today, payee: "Ajeno")
      movement("Mío")

      get transactions_path

      expect(listed).to eq([ "Mío" ])
    end

    it "hace las mismas consultas con 1 y con 30 movimientos (sin N+1)" do
      movement("Uno", category: supermarket)
      Transfer.record!(household: household, from: checking, to: savings, amount_cents: 100, date: today)
      count_queries = lambda do
        queries = 0
        callback = ->(*, payload) { queries += 1 unless payload[:name].in?([ "SCHEMA", "TRANSACTION" ]) }
        ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { get transactions_path(account_id: checking.id) }
        queries
      end

      few = count_queries.call
      create_list(:transaction, 15, account: checking, date: today, category: supermarket)
      7.times { Transfer.record!(household: household, from: checking, to: savings, amount_cents: 100, date: today) }

      expect(count_queries.call).to eq(few)
    end
  end
end
