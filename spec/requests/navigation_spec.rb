require "rails_helper"

RSpec.describe "Navigation", type: :request do
  let(:user) { create(:user, :with_household) }

  before { sign_in_as(user) }

  it "renders the dashboard with an empty state" do
    get dashboard_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("dashboard.show.empty"))
  end

  %i[ movements accounts budget goals net_worth settings ].each do |section|
    it "renders #{section} as coming soon" do
      get public_send("#{section}_path")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("coming_soon.title"))
    end
  end
end
