require "rails_helper"

RSpec.describe "Categories", type: :system do
  let(:password) { "password1234" }
  let(:user) { User.create_with_household!(email: "cat@example.com", password: password) }
  let(:household) { Household.joins(:memberships).find_by!(memberships: { user_id: user.id }) }

  # Los botones Subir/Bajar y los enlaces de cada fila se nombran con aria-label
  around do |example|
    Capybara.enable_aria_label = true
    example.run
  ensure
    Capybara.enable_aria_label = false
  end

  def sign_in
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: password
    click_button I18n.t("sessions.new.submit")
    expect(page).to have_current_path(dashboard_path)
  end

  def root_names(kind = "expense")
    within("section[aria-labelledby='categories-#{kind}']") do
      all("ul > li > div p.font-medium", minimum: 1).map(&:text)
    end
  end

  it "llega desde Ajustes con las categorías por defecto y crea una subcategoría" do
    sign_in
    visit settings_path
    click_link I18n.t("categories.index.title")

    expect(page).to have_css("h2", text: "Gastos")
    expect(root_names.first(2)).to eq([ "Alimentación", "Vivienda y suministros" ])
    expect(root_names("income")).to include("Nómina")

    click_link I18n.t("categories.index.add_child_to", name: "Transporte")
    expect(page).to have_select("Categoría principal", selected: "Transporte")
    fill_in "Nombre", with: "Gasolina"
    find("label", text: I18n.t("categories.colors.red"), visible: :all).click
    click_button I18n.t("categories.form.submit")

    expect(page).to have_content(I18n.t("categories.create.success", name: "Gasolina"))
    within("ul[aria-label='#{I18n.t('categories.index.children_of', name: 'Transporte')}']") do
      expect(page).to have_content("Gasolina")
    end
  end

  it "reordena con Subir y Bajar y archiva un padre con sus hijas" do
    transport = household.categories.find_by!(name: "Transporte")
    create(:category, :child, household: household, parent: transport, name: "Gasolina")
    sign_in
    visit categories_path

    click_button I18n.t("categories.index.move_up", name: "Transporte")
    expect(page).to have_button(I18n.t("categories.index.move_up", name: "Hogar y familia"))
    expect(root_names.index("Transporte")).to eq(root_names.index("Hogar y familia") - 1)

    click_link I18n.t("categories.index.edit_named", name: "Transporte")
    accept_confirm { click_button I18n.t("categories.edit.archive") }

    expect(page).to have_content(I18n.t("categories.archives.create.success", name: "Transporte"))
    expect(root_names).not_to include("Transporte")
    find("summary", text: I18n.t("categories.index.archived", count: 2)).click
    expect(page).to have_content("Transporte › Gasolina")
  end

  it "ofrece desarchivar al crear una con el nombre de una archivada" do
    household.categories.find_by!(name: "Ocio").archive!
    sign_in
    visit new_category_path(kind: "expense")

    fill_in "Nombre", with: "ocio"
    click_button I18n.t("categories.form.submit")
    click_button I18n.t("categories.new.unarchive", name: "Ocio")

    expect(page).to have_content(I18n.t("categories.archives.destroy.success", name: "Ocio"))
    expect(root_names).to include("Ocio")
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

    it "muestra la lista y el formulario sin scroll horizontal" do
      transport = household.categories.find_by!(name: "Transporte")
      create(:category, :child, household: household, parent: transport, name: "Una subcategoría con nombre largo")
      sign_in

      [ categories_path, new_category_path, edit_category_path(transport) ].each do |path|
        visit path
        # Con la emulación móvil, innerWidth crece con el contenido que desborda: se compara
        # con clientWidth (390). Y como body tiene overflow-x-hidden, se mira cada control.
        overflowing = page.evaluate_script(<<~JS)
          [...document.querySelectorAll("main a, main button, main select")]
            .filter(el => el.getBoundingClientRect().right > document.documentElement.clientWidth + 1)
            .map(el => el.textContent.trim())
        JS
        expect(overflowing).to be_empty, "#{path}: #{overflowing.first(3).inspect}"
      end
    end
  end
end
