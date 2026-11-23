require "rails_helper"

RSpec.describe "Lista de movimientos", type: :system do
  let(:password) { "password1234" }
  let(:user) { User.create_with_household!(email: "lista@example.com", password: password) }
  let(:household) { Household.joins(:memberships).find_by!(memberships: { user_id: user.id }) }
  let!(:checking) { create(:account, household: household, name: "Corriente BBVA", opening_balance_cents: 100_000) }
  let!(:savings) { create(:account, household: household, name: "Ahorro") }
  let(:food) { household.categories.find_by!(name: "Alimentación") }
  let(:transport) { household.categories.find_by!(name: "Transporte") }

  def sign_in
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: password
    click_button I18n.t("sessions.new.submit")
    expect(page).to have_current_path(dashboard_path)
  end

  def movement(payee, account: checking, **attributes)
    create(:transaction, account: account, date: Date.current, payee: payee, **attributes)
  end

  it "filtra por cuenta, categoría y texto, y la URL conserva los filtros" do
    movement("Mercadona", category: food)
    movement("Mercadona en ahorro", account: savings, category: food)
    movement("Gasolinera", category: transport)
    movement("Lidl", category: food)
    sign_in

    click_link I18n.t("navigation.movements"), match: :first
    expect(page).to have_css("h1", text: I18n.t("transactions.index.title"))
    expect(page).to have_content("Gasolinera")

    select "Corriente BBVA", from: I18n.t("transactions.filters.account")
    select "Alimentación (con subcategorías)", from: I18n.t("transactions.filters.category")
    fill_in I18n.t("transactions.filters.q"), with: "mercadona"
    click_button I18n.t("transactions.filters.submit")

    expect(page).to have_no_content("Gasolinera")
    expect(page).to have_no_content("Lidl")
    expect(page).to have_no_content("Mercadona en ahorro")
    expect(page).to have_link("Mercadona")
    expect(page).to have_current_path(/account_id=#{checking.id}/)
    expect(page).to have_current_path(/category_id=#{food.id}/)
    expect(page).to have_current_path(/q=mercadona/)
    expect(page).to have_content(I18n.t("transactions.index.columns.balance"))

    refresh
    expect(page).to have_select(I18n.t("transactions.filters.account"), selected: "Corriente BBVA")
    expect(page).to have_no_content("Gasolinera")

    click_link I18n.t("transactions.filters.clear")
    expect(page).to have_content("Gasolinera")
  end

  context "en móvil (390 px)" do
    before do
      page.driver.browser.execute_cdp(
        "Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 2, mobile: true
      )
    end

    after do
      page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    rescue Selenium::WebDriver::Error::WebDriverError
      nil
    end

    it "muestra una lista, no una tabla, sin scroll horizontal" do
      long = create(:account, household: household, name: "Cuenta de ahorro con un nombre bastante largo para el móvil")
      movement("Un beneficiario con un nombre larguísimo que no cabe en una línea", category: food, status: "pending")
      Transfer.record!(household: household, from: checking, to: long, amount_cents: 123_456_78, date: Date.current)
      sign_in

      [ transactions_path, transactions_path(account_id: checking.id) ].each do |path|
        visit path
        expect(page).to have_no_css("table")
        expect(page).to have_css("ul li", text: "Un beneficiario")

        # Con emulación móvil, innerWidth crece con lo que desborda: se compara con clientWidth
        overflow = page.evaluate_script(<<~JS)
          ({
            scroll: document.documentElement.scrollWidth - document.documentElement.clientWidth,
            controls: [...document.querySelectorAll("main a, main button, main select, main input")]
              .filter(el => el.getClientRects().length && el.getBoundingClientRect().right > document.documentElement.clientWidth + 1)
              .map(el => el.textContent.trim() || el.name)
          })
        JS
        expect(overflow["scroll"]).to be <= 0, "#{path}: scroll horizontal de #{overflow["scroll"]} px"
        expect(overflow["controls"]).to be_empty, "#{path}: #{overflow["controls"].first(3).inspect}"
      end
    end
  end
end
