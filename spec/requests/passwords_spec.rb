require "rails_helper"

RSpec.describe "Passwords", type: :request do
  describe "GET /passwords/:token/edit" do
    let(:user) { create(:user, :with_household) }

    it "marks both password fields with the fixed autocomplete token" do
      get edit_password_path(user.password_reset_token)

      expect(response).to have_http_status(:ok)
      expect(response.body.scan('autocomplete="new-password"').size).to eq(2)
      expect(response.body).not_to include("nuevo password")
    end
  end
end
