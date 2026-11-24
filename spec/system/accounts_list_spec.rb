require "rails_helper"

RSpec.describe "Lista y detalle de cuentas (US-0102)", type: :system do
  let(:password) { "password1234" }
  let(:user) { User.create_with_household!(email: "cuentas@example.com", password: password) }
  let(:household) { Household.joins(:memberships).find_by!(memberships: { user_id: user.id }) }
  let!(:checking) { create(:account, household: household, name: "Corriente BBVA", opening_balance_cents: 100_000) }
  let!(:visa) { create(:account, :credit_card, household: household, name: "Visa", opening_balance_cents: -45_000) }
  let!(:old) { create(:account, :closed, household: household, name: "Cuenta antigua") }

  def sign_in
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: password
    click_button I18n.t("sessions.new.submit")
    expect(page).to have_current_path(dashboard_path)
  end

  # Chart.js dibuja en el canvas: si hay píxeles no transparentes, se ha dibujado
  def chart_drawn?
    page.evaluate_script(<<~JS)
      (() => {
        const canvas = document.querySelector("[data-controller=balance-chart] canvas")
        if (!canvas || !canvas.width) return false
        const data = canvas.getContext("2d").getImageData(0, 0, canvas.width, canvas.height).data
        for (let i = 3; i < data.length; i += 4) if (data[i] > 0) return true
        return false
      })()
    JS
  end

  def expect_chart_drawn
    drawn = 50.times.any? { chart_drawn? || (sleep(0.1) && false) }
    expect(drawn).to be(true), "el gráfico no se dibujó en 5 s"
  end

  it "agrupa las cuentas, pliega las cerradas y abre el detalle con su gráfico" do
    create(:transaction, account: checking, amount_cents: -25_000, date: Date.current - 10)
    sign_in

    visit accounts_path
    within("section[aria-labelledby='group-cash_and_banks']") { expect(page).to have_link(href: account_path(checking)) }
    within("section[aria-labelledby='group-cards_and_loans']") { expect(page).to have_link(href: account_path(visa)) }
    expect(page).to have_no_link(href: account_path(old))

    find("details#closed-accounts summary").click
    expect(page).to have_link(href: account_path(old))

    find("a[href='#{account_path(checking)}']").click
    expect(page).to have_css("h1", text: "Corriente BBVA")
    expect(page).to have_content("750,00 €")
    expect(page).to have_css("canvas[aria-label*='de 1.000,00 € a 750,00 €']")
    expect_chart_drawn

    page.execute_script("document.documentElement.classList.add('dark')")
    expect_chart_drawn

    find("summary", text: I18n.t("accounts.show.chart_table")).click
    expect(page).to have_css("details[open] table tbody tr", count: 90)
  end

  it "una página sin gráfico no descarga Chart.js" do
    sign_in
    visit accounts_path
    expect(page).to have_css("h1", text: I18n.t("navigation.accounts"))

    loaded = page.evaluate_script("performance.getEntriesByType('resource').some(entry => entry.name.includes('/chartjs-'))")
    expect(loaded).to be(false)
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

    it "la lista y el detalle caben sin scroll horizontal" do
      create(:account, household: household, name: "Una cuenta de ahorro con un nombre bastante largo", opening_balance_cents: 123_456_789)
      create(:transaction, account: checking, amount_cents: -25_000, date: Date.current - 10)
      sign_in

      [ accounts_path, account_path(checking) ].each do |path|
        visit path
        expect(page).to have_css("h1")
        overflow = page.evaluate_script(<<~JS)
          ({
            scroll: document.documentElement.scrollWidth - document.documentElement.clientWidth,
            controls: [...document.querySelectorAll("main a, main button, main canvas")]
              .filter(el => el.getClientRects().length && el.getBoundingClientRect().right > document.documentElement.clientWidth + 1)
              .map(el => el.textContent.trim() || el.tagName)
          })
        JS
        expect(overflow["scroll"]).to be <= 0, "#{path}: scroll horizontal de #{overflow["scroll"]} px"
        expect(overflow["controls"]).to be_empty, "#{path}: #{overflow["controls"].first(3).inspect}"
      end
    end
  end
end
