require 'rails_helper'

RSpec.describe "Homes", type: :request do
  describe "GET root page" do
    it "redirects to the login page" do
      get root_path
      expect(response).to have_http_status(200)
    end
  end

  describe "GET /dashboard" do
    before { Rails.cache.clear }

    context "when the user is authenticated" do
      let(:user) { create(:user, :with_household) }
      before { sign_in_as(user) }

      it "returns a successful response" do
        get dashboard_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "when the user is not authenticated" do
      it "redirects to the login page" do
        get dashboard_path
        expect(response).to redirect_to(new_session_path)
      end
    end
  end
end
