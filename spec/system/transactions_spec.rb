require "rails_helper"

RSpec.describe "Transactions", type: :system do
  let(:password) { "password1234" }
  let(:user) { User.create_with_household!(email: "mov@example.com", password: password) }
  let(:household) { Household.joins(:memberships).find_by!(memberships: { user_id: user.id }) }
  let!(:account) { create(:account, household: household, name: "Corriente BBVA", opening_balance_cents: 100_000) }

  def sign_in
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: password
    click_button I18n.t("sessions.new.submit")
    expect(page).to have_current_path(dashboard_path)
  end

  it "registra un gasto y el saldo de la cuenta baja (PRD-F1 §7)" do
    sign_in
    visit account_path(account)
    expect(page).to have_content("1.000,00 €")

    click_link I18n.t("accounts.show.new_transaction")
    expect(page).to have_select("Cuenta", selected: "Corriente BBVA (EUR)")
    fill_in "Importe", with: "12,50"
    select "Alimentación (general)", from: "Categoría"
    fill_in "Beneficiario", with: "Mercadona"
    click_button I18n.t("transactions.form.submit")

    expect(page).to have_content(I18n.t("transactions.create.success"))
    expect(page).to have_css("h1", text: "Corriente BBVA")
    expect(page).to have_content("987,50 €")
    expect(page).to have_content("Mercadona")
    expect(page).to have_content("−12,50 €")
  end

  it "filtra las categorías por la pestaña y borra el movimiento" do
    sign_in
    visit new_transaction_path(account_id: account.id)

    category = find_field("Categoría")
    expect(category).to have_css("optgroup[label='Transporte']", visible: :all)
    expect(category).to have_no_css("optgroup[label='Nómina']:not([hidden])", visible: :all)

    find("label", text: I18n.t("transactions.directions.income")).click
    expect(category).to have_no_css("optgroup[label='Transporte']:not([hidden])", visible: :all)
    select "Nómina (general)", from: "Categoría"
    fill_in "Importe", with: "2.000"
    click_button I18n.t("transactions.form.submit")
    expect(page).to have_content("3.000,00 €")

    click_link "Nómina"
    accept_confirm { click_button I18n.t("transactions.edit.destroy") }
    expect(page).to have_content(I18n.t("transactions.destroy.success"))
    expect(page).to have_content("1.000,00 €")
  end

  it "duplica un gasto desde la lista en el modal y solo lo guarda al pulsar Guardar (US-0111)" do
    create(:transaction, account: account, amount_cents: -6_000, date: Date.current, payee: "Gasolinera Repsol")
    sign_in
    visit transactions_path

    first("a[aria-label='#{I18n.t('transactions.index.duplicate_named', name: 'Gasolinera Repsol')}']", minimum: 1).click
    within("dialog[open]") do
      expect(page).to have_field("Importe", with: "60,00")
      expect(page).to have_field("Beneficiario", with: "Gasolinera Repsol")
      expect(Transaction.count).to eq(1)
      click_button I18n.t("transactions.form.submit")
    end

    expect(page).to have_content(I18n.t("transactions.create.success"))
    expect(page).to have_no_css("dialog[open]")
    expect(Transaction.where(payee: "Gasolinera Repsol", amount_cents: -6_000).count).to eq(2)
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

    it "el formulario y la cuenta con movimientos caben sin cortar controles" do
      transaction = create(:transaction, account: account, payee: "Un beneficiario con un nombre bastante largo")
      sign_in

      [ new_transaction_path, edit_transaction_path(transaction), account_path(account) ].each do |path|
        visit path
        # Con emulación móvil, innerWidth crece con lo que desborda: se compara con clientWidth
        overflowing = page.evaluate_script(<<~JS)
          [...document.querySelectorAll("main a, main button, main select, main input")]
            .filter(el => el.getBoundingClientRect().right > document.documentElement.clientWidth + 1)
            .map(el => el.textContent.trim() || el.name)
        JS
        expect(overflowing).to be_empty, "#{path}: #{overflowing.first(3).inspect}"
      end
    end
  end
end
