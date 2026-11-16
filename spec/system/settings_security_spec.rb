require "rails_helper"

RSpec.describe "Settings security", type: :system do
  let(:password) { "password1234" }
  let(:user) { create(:user, :with_household, password: password) }

  before { driven_by(:rack_test) }

  it "shows the sessions with the current one marked and closes another" do
    other = user.sessions.create!(
      user_agent: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
      ip_address: "203.0.113.9"
    )

    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: password
    click_button I18n.t("sessions.new.submit")

    visit settings_sessions_path
    expect(page).to have_content(I18n.t("settings.security.title"))
    expect(page).to have_content(I18n.t("settings.sessions.title"))
    expect(page).to have_content(I18n.t("settings.sessions.current"))
    expect(page).to have_content("Safari")
    expect(page).to have_content("203.0.113.9")

    within("li", text: "Safari") do
      click_button I18n.t("settings.sessions.close")
    end

    expect(page).to have_current_path(settings_sessions_path)
    expect(Session.exists?(other.id)).to be false
    expect(page).to have_no_css("li", text: "Safari")
  end
end
