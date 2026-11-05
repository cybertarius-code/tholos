require 'rails_helper'

RSpec.describe "Homes", type: :request do
  include_context "authentication helpers"

  describe "GET root page" do
    it "redirects to the login page" do
      get root_path
      expect(response).to have_http_status(200)
    end
  end

  describe "GET /dashboard/index" do
    context "when the user is authenticated" do
      let(:user) { FactoryBot.create(:user) }
      before do
        sign_in_as(user)
      end

      it "returns a successful response" do
        get user_home_path
        expect(response).to have_http_status(200)
      end
    end

    context "when the user is not authenticated" do
      it "redirects to the login page" do
        get user_home_path
        expect(response).to redirect_to(new_session_path)
      end

    when " the user tries 10 times to access the dashboard without being authenticated" do
      it "redirects to the login page" do
        10.times do
          get user_home_path
          expect(response).to redirect_to(new_session_path)
        end
      end
    end
  end

end
