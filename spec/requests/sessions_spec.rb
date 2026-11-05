require 'rails_helper'

RSpec.describe "Sessions", type: :request do
  include_context "authentication helpers"

  describe "POST /session" do
    before { Rails.cache.clear }

    let(:user) { create(:user) }

    context "with valid credentials" do
      it "creates a new session and redirects to the dashboard" do
        post session_path, params: { email_address: user.email_address, password: user.password }
        expect(response).to redirect_to(user_home_path)
        follow_redirect!
        expect(response.body).to include(I18n.t("dashboard.index.welcome"))
      end
    end

    context "with invalid credentials" do
      it "does not create a session and re-renders the login page with an error message" do
        post session_path, params: { email_address: user.email_address, password: "wrongpassword" }
        expect(response).to have_http_status(:found)
        follow_redirect!
        expect(flash[:alert]).to eq(I18n.t("sessions.create.invalid_credentials"))
      end
    end

    context "when the user makes too many login attempts" do
      let(:bad_credentials) { { email_address: user.email_address, password: "wrongpassword" } }
      before { 10.times { post session_path, params: bad_credentials } }

      it "blocks the user with a warning" do
        post session_path, params: bad_credentials

        expect(response).to redirect_to(new_session_path)
        follow_redirect!
        expect(flash[:alert]).to eq(I18n.t("sessions.create.rate_limit"))
      end

      it "allows attempts again after 3 minutes" do
        post session_path, params: bad_credentials

        travel 3.minutes + 1.second do
          post session_path, params: bad_credentials
          expect(flash[:alert]).not_to eq(I18n.t("sessions.create.rate_limit"))
        end
      end
    end
  end

  describe "DELETE /sessions/:id" do
    let(:user) { create(:user) }

    before do
      sign_in_as(user)
    end

    it "destroys the session and redirects to the login page" do
      delete session_path(user)
      expect(response).to redirect_to(new_session_path)
      follow_redirect!
      expect(flash[:alert]).to eq(I18n.t("sessions.destroy.success"))
    end
  end
end
