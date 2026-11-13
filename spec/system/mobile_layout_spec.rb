require "rails_helper"

RSpec.describe "Mobile layout", type: :system do
  let(:password) { "password1234" }
  let(:user) { create(:user, :with_household, password: password) }

  before do
    # headless Chrome enforce un ancho mínimo de ventana de 500 px;
    # la emulación CDP sí permite un viewport real de 390 px.
    page.driver.browser.execute_cdp(
      "Emulation.setDeviceMetricsOverride",
      width: 390, height: 844, deviceScaleFactor: 2, mobile: true
    )
  end

  def expect_no_horizontal_scroll
    scroll_width, inner_width = page.evaluate_script(
      "document.documentElement.scrollWidth + ',' + window.innerWidth"
    ).split(",").map(&:to_i)
    expect(scroll_width).to be <= inner_width
  end

  it "recorre landing, login, dashboard y logout sin scroll horizontal" do
    visit root_path
    expect(page).to have_current_path(root_path)
    expect(page.evaluate_script("window.innerWidth")).to eq(390)
    expect_no_horizontal_scroll

    visit new_session_path
    expect_no_horizontal_scroll

    fill_in "email_address", with: user.email_address
    fill_in "password", with: password
    click_button I18n.t("sessions.new.submit")
    expect(page).to have_current_path(dashboard_path)
    expect(page).to have_content(I18n.t("dashboard.show.welcome"))
    expect_no_horizontal_scroll

    find("nav summary", text: I18n.t("navigation.more")).click
    find("details").click_button(I18n.t("shared.sign_out"))
    expect(page).to have_current_path(new_session_path)
    expect_no_horizontal_scroll
  end
end
