require "rails_helper"

RSpec.describe "Layout navigation", type: :system do
  let(:password) { "password1234" }
  let(:user) { create(:user, :with_household, password: password) }

  def sign_in
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: password
    click_button I18n.t("sessions.new.submit")
  end

  it "shows the complete active sidebar on desktop" do
    page.driver.browser.manage.window.resize_to(1280, 900)
    sign_in

    expect(page).to have_css('aside nav[aria-label="Principal"]', visible: true)
    %w[Dashboard Movimientos Cuentas Presupuesto Metas Patrimonio Ajustes].each do |label|
      expect(page).to have_css('aside nav a', text: label, visible: true)
    end
    expect(page).to have_css('aside nav a[aria-current="page"]', text: "Dashboard")
    expect(page).to have_button(I18n.t("navigation.quick_movement"), disabled: true)
  end

  it "shows the mobile navigation and more menu without horizontal scrolling" do
    page.driver.browser.manage.window.resize_to(390, 844)
    sign_in

    expect(page).to have_css('nav[aria-label="Principal"]', visible: true)
    expect(page).to have_css("nav summary", text: I18n.t("navigation.more"), visible: true)
    expect(page).to have_button(I18n.t("navigation.quick_movement"), disabled: true)
    expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true)

    find("nav summary", text: I18n.t("navigation.more")).click
    expect(page).to have_link("Presupuesto", visible: true)
    expect(page).to have_button(I18n.t("shared.sign_out"), visible: true)
  end
end
