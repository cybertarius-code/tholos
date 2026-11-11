require "rails_helper"

RSpec.describe "Theme preference", type: :request do
  before { sign_in_as(create(:user, :with_household)) }

  it "renders the dark class when the dark theme cookie is set" do
    cookies[:theme] = "dark"

    get settings_path

    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML(response.body).at_css("html")["class"]).to eq("dark")
  end

  it "does not force a theme without a cookie" do
    get settings_path

    html = Nokogiri::HTML(response.body)
    expect(html.at_css("html")["class"]).to be_blank
    expect(html.at_css("head script").text).to include("prefers-color-scheme")
  end
end
