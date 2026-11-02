require "rails_helper"

RSpec.describe "Smoke test", type: :system do
  it "carga la página principal" do
    visit root_path
    expect(page).to have_css("body")
  end
end