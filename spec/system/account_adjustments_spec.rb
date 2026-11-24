require "rails_helper"

# Ajuste de saldo: test obligatorio de PRD-F1 §7 (US-0108)
RSpec.describe "Account adjustments", type: :system do
  let(:password) { "password1234" }
  let(:user) { create(:user, :with_household, password: password) }
  let(:household) { Household.joins(:memberships).find_by!(memberships: { user_id: user.id }) }
  let!(:account) { create(:account, household: household, name: "Corriente BBVA", opening_balance_cents: 100_000) }

  def sign_in
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: password
    click_button I18n.t("sessions.new.submit")
    expect(page).to have_current_path(dashboard_path)
  end

  it "ajusta el saldo a la baja y el ajuste sale en la lista con su etiqueta" do
    sign_in
    visit account_path(account)
    click_link I18n.t("accounts.show.adjust_balance")

    fill_in "Saldo real", with: "985,40"
    click_button I18n.t("accounts.adjustments.new.submit")

    expect(page).to have_content(I18n.t("accounts.adjustments.create.success"))
    expect(page).to have_current_path(account_path(account))
    expect(page).to have_content("985,40 €")
    expect(page).to have_content("Ajuste de saldo")
    expect(page).to have_content("−14,60 €")

    visit transactions_path
    expect(page).to have_content("Ajuste de saldo")
    expect(page).to have_css("span", text: I18n.t("transactions.index.adjustment"))
  end

  it "si el saldo ya coincide no crea nada y lo dice" do
    sign_in
    visit new_account_adjustment_path(account)

    fill_in "Saldo real", with: "1000"
    click_button I18n.t("accounts.adjustments.new.submit")

    expect(page).to have_content(I18n.t("accounts.adjustments.create.unchanged"))
    expect(page).to have_content(I18n.t("accounts.show.no_transactions"))
  end
end
