require "rails_helper"

RSpec.describe "Transfers", type: :system do
  let(:password) { "password1234" }
  let(:user) { User.create_with_household!(email: "transfer@example.com", password: password) }
  let(:household) { Household.joins(:memberships).find_by!(memberships: { user_id: user.id }) }
  let!(:checking) { create(:account, household: household, name: "Corriente BBVA", opening_balance_cents: 100_000) }
  let!(:savings) { create(:account, household: household, name: "Ahorro", kind: "savings") }

  def sign_in
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: password
    click_button I18n.t("sessions.new.submit")
    expect(page).to have_current_path(dashboard_path)
  end

  it "registra una transferencia y la ve en las dos cuentas (PRD-F1 §7)" do
    sign_in
    visit account_path(checking)

    click_link I18n.t("accounts.show.new_transfer")
    expect(page).to have_select("Desde", selected: "Corriente BBVA (EUR)")
    select "Ahorro (EUR)", from: "Hacia"
    fill_in "Importe", with: "300"
    click_button I18n.t("transfers.form.submit")

    expect(page).to have_content(I18n.t("transfers.create.success"))
    expect(page).to have_css("h1", text: "Corriente BBVA")
    expect(page).to have_content("700,00 €")
    expect(page).to have_content("Transferencia a Ahorro")
    expect(page).to have_content("−300,00 €")

    click_link "Ahorro"
    expect(page).to have_css("h1", text: "Ahorro")
    expect(page).to have_content("Transferencia desde Corriente BBVA")
    expect(page).to have_content("300,00 €")
  end

  it "paga la tarjeta y la deja a cero; borrar un lado borra la transferencia" do
    visa = create(:account, :credit_card, household: household, name: "Visa", opening_balance_cents: -45_000)
    sign_in
    visit account_path(visa)
    expect(page).to have_content("−450,00 €")

    click_link I18n.t("accounts.show.pay_account")
    expect(page).to have_select("Hacia", selected: "Visa (EUR)")
    select "Corriente BBVA (EUR)", from: "Desde"
    fill_in "Importe", with: "450"
    click_button I18n.t("transfers.form.submit")
    expect(page).to have_content("550,00 €")

    click_link "Visa"
    expect(page).to have_content("0,00 €")

    click_link I18n.t("accounts.show.transfer_from")
    expect(page).to have_css("h1", text: I18n.t("transfers.edit.title"))
    accept_confirm { click_button I18n.t("transfers.edit.destroy") }

    expect(page).to have_content(I18n.t("transfers.destroy.success"))
    expect(page).to have_content("1.000,00 €")
    expect(Transaction.count).to eq(0)
  end

  it "muestra el error si se transfiere a la misma cuenta" do
    sign_in
    visit new_transfer_path(account_id: checking.id)
    select "Corriente BBVA (EUR)", from: "Hacia"
    fill_in "Importe", with: "10"
    click_button I18n.t("transfers.form.submit")

    expect(page).to have_content(I18n.t("activerecord.errors.models.transfer.attributes.to_account_id.same_as_from"))
    expect(Transfer.count).to eq(0)
  end

  it "edita una transferencia y cambia los dos lados" do
    Transfer.record!(household: household, from: checking, to: savings, amount_cents: 30_000, date: Date.current)
    sign_in
    visit account_path(checking)

    click_link I18n.t("accounts.show.transfer_to")
    expect(page).to have_css("h1", text: I18n.t("transfers.edit.title"))
    expect(page).to have_field("Importe", with: "300,00")
    fill_in "Importe", with: "125,50"
    fill_in "Notas", with: "Corregido"
    click_button I18n.t("transfers.form.submit")

    expect(page).to have_content(I18n.t("transfers.update.success"))
    expect(page).to have_content("874,50 €")
    click_link "Ahorro"
    expect(page).to have_content("125,50 €")
  end

  it "muestra el error con monedas distintas o una cuenta cerrada y no guarda nada" do
    create(:account, household: household, name: "Sabadell USD", currency: "USD")
    closed = create(:account, household: household, name: "Vieja")
    sign_in
    visit new_transfer_path(account_id: checking.id)
    select "Sabadell USD (USD)", from: "Hacia"
    fill_in "Importe", with: "10"
    click_button I18n.t("transfers.form.submit")
    expect(page).to have_content(I18n.t("activerecord.errors.models.transfer.attributes.to_account_id.currency_mismatch"))

    # Se cierra con el formulario ya abierto: el select aún la ofrece
    select "Vieja (EUR)", from: "Hacia"
    closed.update!(status: "closed")
    fill_in "Importe", with: "10"
    click_button I18n.t("transfers.form.submit")
    expect(page).to have_content(I18n.t("activerecord.errors.models.transfer.attributes.to_account_id.closed"))

    expect(Transaction.count).to eq(0)
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

    it "el formulario y la cuenta con transferencias caben sin cortar controles" do
      long = create(:account, household: household, name: "Cuenta de ahorro con un nombre bastante largo")
      transfer = Transfer.record!(household: household, from: checking, to: long, amount_cents: 1_000, date: Date.current)
      sign_in

      [ new_transfer_path, edit_transfer_path(transfer), account_path(checking) ].each do |path|
        visit path
        # Con emulación móvil, innerWidth crece con lo que desborda: se compara con clientWidth
        overflowing = page.evaluate_script(<<~JS)
          [...document.querySelectorAll("main a, main button, main select, main input, main textarea")]
            .filter(el => el.getBoundingClientRect().right > document.documentElement.clientWidth + 1)
            .map(el => el.textContent.trim() || el.name)
        JS
        expect(overflowing).to be_empty, "#{path}: #{overflowing.first(3).inspect}"
      end
    end
  end
end
