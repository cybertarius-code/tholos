require "rails_helper"

# Importar un extracto de Sabadell: subir, corregir, decidir y confirmar (US-0113)
RSpec.describe "Imports", type: :system do
  let(:password) { "password1234" }
  let(:user) { create(:user, :with_household, password: password) }
  let(:household) { Household.joins(:memberships).find_by!(memberships: { user_id: user.id }) }
  let!(:account) do
    create(:account, household: household, name: "Corriente Sabadell", opening_balance_cents: 100_000, opening_date: Date.new(2026, 1, 1))
  end
  let!(:restaurants) { create(:category, household: household, name: "Restaurantes") }
  let!(:other_income) { create(:category, :income, household: household, name: "Otros ingresos") }
  let!(:fees) { create(:category, household: household, name: "Comisiones bancarias") }

  def sign_in
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: password
    click_button I18n.t("sessions.new.submit")
    expect(page).to have_current_path(dashboard_path)
  end

  def within_line(line, &)
    row = ImportRow.find_by!(line: line)
    within("turbo-frame#import_row_#{row.id}", &)
  end

  def decide(line, choice, concept: nil)
    within_line(line) do
      fill_in "Concepto", with: concept if concept
      select choice, from: "Es…"
      click_button "Guardar"
      expect(page).to have_select("Es…", selected: choice)
    end
  end

  it "sube el extracto, corrige una fila, decide las demás y confirma" do
    sign_in
    visit account_path(account)
    click_link I18n.t("accounts.show.import_statement")

    attach_file "Extracto", file_fixture("sabadell.txt")
    click_button I18n.t("imports.new.submit")

    expect(page).to have_content("Extracto cargado con 5 filas")
    expect(page).to have_content("Anterior al corte", count: 2)

    click_button I18n.t("imports.show.commit")
    expect(page).to have_content("Faltan por decidir las filas: 3, 4 y 5")

    decide(3, "Restaurantes", concept: "Farmacia")
    decide(4, "Otros ingresos")
    decide(5, "Omitir")
    expect(ImportRow.find_by!(line: 3).concept).to eq("Farmacia")

    click_button I18n.t("imports.show.commit")

    expect(page).to have_content("Extracto confirmado. Se han creado 2 movimientos.")
    expect(page).to have_current_path(account_path(account))
    expect(page).to have_content("Farmacia")
    expect(page).to have_content("1.047,60 €")
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

    it "la subida y la revisión caben sin scroll horizontal" do
      import = Imports::Stage.call(account: account, file: Rack::Test::UploadedFile.new(file_fixture("sabadell.txt"))).import
      sign_in

      [ new_account_import_path(account), account_import_path(account, import) ].each do |path|
        visit path
        expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true), path
      end
    end
  end
end
