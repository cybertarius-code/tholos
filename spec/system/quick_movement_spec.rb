require "rails_helper"

# Modal "+ Movimiento" (US-0109)
RSpec.describe "Quick movement", type: :system do
  let(:password) { "password1234" }
  let(:user) { User.create_with_household!(email: "rapido@example.com", password: password) }
  let(:household) { Household.joins(:memberships).find_by!(memberships: { user_id: user.id }) }
  let!(:account) { create(:account, household: household, name: "Corriente BBVA", opening_balance_cents: 100_000) }
  let!(:savings) { create(:account, household: household, name: "Ahorro", kind: "savings", opening_balance_cents: 500_000) }

  def sign_in
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: password
    click_button I18n.t("sessions.new.submit")
    expect(page).to have_current_path(dashboard_path)
  end

  def open_modal
    click_link I18n.t("navigation.quick_movement")
    expect(page).to have_css("dialog[open]")
  end

  def active_element(property)
    page.evaluate_script("document.activeElement.#{property}")
  end

  it "registra un gasto sin salir de la página y recuerda la última cuenta" do
    sign_in
    visit account_path(account)
    expect(page).to have_content("1.000,00 €")

    open_modal
    within("dialog") do
      expect(page).to have_css("nav a[aria-current=page]", text: I18n.t("quick_movement.tabs.expense"))
      expect(active_element(:name)).to eq("transaction[amount_input]")
      expect(page).to have_field("Importe") { |field| field[:inputmode] == "decimal" }

      fill_in "Importe", with: "4,20"
      select "Corriente BBVA (EUR)", from: "Cuenta"
      select "Restaurantes (general)", from: "Categoría"
      find_field("Importe").send_keys(:enter)
    end

    expect(page).to have_no_css("dialog")
    expect(page).to have_content(I18n.t("transactions.create.success"))
    expect(page).to have_current_path(account_path(account))
    expect(page).to have_content("995,80 €")
    expect(page).to have_content("−4,20 €")
    expect(active_element(:id)).to eq("quick_movement")

    # Se puede volver a abrir (el aviso ya no tapa el botón) y la cuenta es la última usada
    open_modal
    expect(page).to have_select("Cuenta", selected: "Corriente BBVA (EUR)")
  end

  it "registra una transferencia desde su pestaña" do
    sign_in
    visit accounts_path
    open_modal

    within("dialog") do
      click_link I18n.t("quick_movement.tabs.transfer")
      expect(page).to have_css("nav a[aria-current=page]", text: I18n.t("quick_movement.tabs.transfer"))
      expect(page).to have_no_field("Categoría")
      select "Corriente BBVA (EUR)", from: "Desde"
      select "Ahorro (EUR)", from: "Hacia"
      fill_in "Importe", with: "100"
      click_button I18n.t("transfers.form.submit")
    end

    expect(page).to have_no_css("dialog")
    expect(page).to have_content(I18n.t("transfers.create.success"))
    expect(page).to have_current_path(accounts_path)
    expect(page).to have_content("900,00 €")
    expect(page).to have_content("5.100,00 €")
  end

  it "la pestaña Ingreso muestra solo categorías de ingreso" do
    sign_in
    open_modal
    within("dialog") { click_link I18n.t("quick_movement.tabs.income") }

    category = find("dialog").find_field("Categoría")
    expect(category).to have_css("optgroup[label='Nómina']:not([hidden])", visible: :all)
    expect(category).to have_no_css("optgroup[label='Transporte']:not([hidden])", visible: :all)
  end

  it "se abre con la tecla n, salvo al escribir en un campo" do
    sign_in
    visit transactions_path

    find("input[name=q]").send_keys("n")
    expect(find("input[name=q]").value).to eq("n")
    expect(page).to have_no_css("dialog")

    find("h1").click
    page.driver.browser.action.send_keys("n").perform
    expect(page).to have_css("dialog[open]")
    expect(find("dialog").find_field("Importe").value).to eq("")
  end

  it "se cierra con Escape y devuelve el foco al botón" do
    sign_in
    open_modal

    page.driver.browser.action.send_keys(:escape).perform
    expect(page).to have_no_css("dialog")
    expect(active_element(:id)).to eq("quick_movement")
  end

  it "sigue abierto con el error junto al campo si falta el importe" do
    sign_in
    open_modal

    within("dialog") do
      # Sin la validación del navegador, para llegar a la del servidor
      page.execute_script("document.querySelector('dialog [name=\"transaction[amount_input]\"]').removeAttribute('required')")
      select "Corriente BBVA (EUR)", from: "Cuenta"
      click_button I18n.t("transactions.form.submit")
    end

    expect(page).to have_css("dialog[open]")
    within("dialog") do
      expect(page).to have_css("#transaction_amount_input_error[role=alert]")
    end
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

    it "ocupa la pantalla entera sin scroll horizontal" do
      sign_in
      open_modal

      size = page.evaluate_script(<<~JS)
        (() => {
          const box = document.querySelector("dialog").getBoundingClientRect()
          return { left: box.left, width: box.width, viewport: document.documentElement.clientWidth,
                   overflow: document.querySelector("dialog").scrollWidth - document.querySelector("dialog").clientWidth }
        })()
      JS
      expect(size["left"]).to eq(0)
      expect(size["width"]).to eq(size["viewport"])
      expect(size["overflow"]).to be <= 0
    end
  end
end
