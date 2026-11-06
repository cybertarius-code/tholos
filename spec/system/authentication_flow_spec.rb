require "rails_helper"

RSpec.describe "Authentication Flow", type: :system do
  let(:password) { "password1234" }
  let(:user) { create(:user, :with_household, password: password) }

  before { driven_by(:rack_test) }

  it "recorre landing, login, dashboard, logout y vuelve al login" do
    # 1. Landing page
    visit root_path
    expect(page).to have_current_path(root_path)
    expect(page).to have_content("Tholos")

    # 2. Tries to access the dashboard without being logged in,and is redirected to the login page
    visit user_home_path
    expect(page).to have_current_path(new_session_path)

    # 3. Login with valid credentials
    fill_in "email_address", with: user.email_address
    fill_in "password", with: password
    click_button I18n.t("sessions.new.submit")

    # 4. Once logged in, the user is redirected to the dashboard
    expect(page).to have_current_path(user_home_path)
    expect(page).to have_content(I18n.t("dashboard.index.welcome"))

    # puts page.current_path
    # puts page.html

    # 5. Close the session and is redirected to the login page
    click_button I18n.t("sessions.destroy.sign_out")
    expect(page).to have_current_path(new_session_path)

    # 6. Dashboard is not accessible anymore, and
    #  the user is redirected to the login page
    visit user_home_path
    expect(page).to have_current_path(new_session_path)
  end
end
