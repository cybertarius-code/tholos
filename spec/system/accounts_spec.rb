require "rails_helper"

RSpec.describe "Accounts", type: :system do
  let(:password) { "password1234" }
  let(:user) { create(:user, :with_household, password: password) }
  let(:household) { Household.joins(:memberships).find_by!(memberships: { user_id: user.id }) }

  def sign_in
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: password
    click_button I18n.t("sessions.new.submit")
    expect(page).to have_current_path(dashboard_path)
  end

  it "crea una cuenta corriente" do
    sign_in
    visit accounts_path
    click_link I18n.t("accounts.index.new"), match: :first

    fill_in "Nombre", with: "Corriente BBVA"
    select "Corriente", from: "Tipo"
    fill_in "Saldo inicial", with: "1250.00"
    fill_in "Fecha del saldo inicial", with: Date.new(2026, 1, 1)
    click_button I18n.t("accounts.form.submit")

    expect(page).to have_content(I18n.t("accounts.create.success"))
    expect(page).to have_css("h1", text: "Corriente BBVA")
    expect(page).to have_content("1.250,00 €")
    expect(page).to have_content("Activo")
  end

  it "pide la deuda inicial de una tarjeta, la cierra y la reabre" do
    sign_in
    visit new_account_path

    fill_in "Nombre", with: "Visa"
    select "Tarjeta de crédito", from: "Tipo"
    expect(page).to have_field("Deuda inicial")
    fill_in "Deuda inicial", with: "300"
    click_button I18n.t("accounts.form.submit")

    expect(page).to have_content("−300,00 €")
    expect(page).to have_content("Pasivo")

    accept_confirm { click_button I18n.t("accounts.show.close") }
    expect(page).to have_content(I18n.t("accounts.closures.create.success_with_balance"))
    expect(page).to have_content(I18n.t("accounts.statuses.closed"))

    click_button I18n.t("accounts.show.reopen")
    expect(page).to have_content(I18n.t("accounts.closures.destroy.success"))
    expect(page).to have_button(I18n.t("accounts.show.close"))
  end

  context "en móvil (390 px)" do
    before do
      page.driver.browser.execute_cdp(
        "Emulation.setDeviceMetricsOverride",
        width: 390, height: 844, deviceScaleFactor: 2, mobile: true
      )
    end

    after do
      page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    rescue Selenium::WebDriver::Error::WebDriverError
      nil
    end

    it "muestra lista, ficha y formulario sin scroll horizontal" do
      account = create(:account, household: household, name: "Cuenta con un nombre bastante largo para móvil")
      sign_in

      [ accounts_path, account_path(account), edit_account_path(account), new_account_path ].each do |path|
        visit path
        expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true), path
      end
    end
  end
end
