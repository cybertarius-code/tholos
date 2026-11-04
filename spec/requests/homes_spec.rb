require 'rails_helper'

RSpec.describe "Homes", type: :request do
  describe "GET root page" do
    it "redirects to the login page" do
      get root_path
      expect(response).to have_http_status(200)
    end
  end

  describe "GET /homes/1" do
    context "when the user is authenticated" do
      before do
        user = FactoryBot.create(:user)
        sign_in_as(user)
      end
      it "returns a successful response" do
        get home_path(user)
        expect(response).to have_http_status(200)
      end
    end
  end
end
