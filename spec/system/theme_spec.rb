require "rails_helper"

RSpec.describe "Theme preference", type: :system do
  let(:password) { "password1234" }
  let(:user) { create(:user, :with_household, password: password) }

  def sign_in
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: password
    click_button I18n.t("sessions.new.submit")
    expect(page).to have_current_path(dashboard_path)
  end

  it "keeps the dark theme after reloading" do
    sign_in
    visit settings_path
    follows_system_theme = page.evaluate_script(
      'document.documentElement.classList.contains("dark") === window.matchMedia("(prefers-color-scheme: dark)").matches'
    )
    expect(follows_system_theme).to be(true)

    select I18n.t("settings.theme.dark"), from: I18n.t("settings.theme.label")

    expect(page).to have_css("html.dark")
    page.refresh

    expect(page).to have_css("html.dark")
    expect(page).to have_select("theme-preference", selected: I18n.t("settings.theme.dark"))

    select I18n.t("settings.theme.light"), from: I18n.t("settings.theme.label")
    expect(page).to have_no_css("html.dark")
    page.refresh
    expect(page).to have_no_css("html.dark")
    expect(page).to have_select("theme-preference", selected: I18n.t("settings.theme.light"))

    select I18n.t("settings.theme.system"), from: I18n.t("settings.theme.label")
    expect(page.evaluate_script(
      'document.documentElement.classList.contains("dark") === window.matchMedia("(prefers-color-scheme: dark)").matches'
    )).to be(true)
    page.refresh
    expect(page.evaluate_script(
      'document.documentElement.classList.contains("dark") === window.matchMedia("(prefers-color-scheme: dark)").matches'
    )).to be(true)
    expect(page).to have_select("theme-preference", selected: I18n.t("settings.theme.system"))
  end
end
