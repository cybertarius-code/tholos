require "rails_helper"

RSpec.describe "Passwords", type: :request do
  describe "POST /passwords" do
    let(:user) { create(:user, :with_household) }

    it "enqueues the reset email for an existing user" do
      expect {
        post passwords_path, params: { email_address: user.email_address }
      }.to have_enqueued_mail(PasswordsMailer, :reset).with(user)

      expect(response).to redirect_to(new_session_path)
    end

    it "enqueues nothing for an unknown address but answers the same" do
      expect {
        post passwords_path, params: { email_address: "nadie@example.com" }
      }.not_to have_enqueued_mail

      expect(response).to redirect_to(new_session_path)
    end
  end

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
