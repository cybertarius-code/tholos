require "rails_helper"

RSpec.describe "Settings", type: :request do
  let(:password) { "password1234" }
  let(:user) { create(:user, :with_household, password: password) }
  let!(:current_session) { sign_in_as(user) }

  describe "GET /settings/sessions" do
    it "shows the user's sessions" do
      get settings_sessions_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("settings.sessions.title"))
      expect(response.body).to include(I18n.t("settings.sessions.current"))
      expect(response.body).to include("127.0.0.1")
    end
  end

  describe "PATCH /settings/password" do
    let(:new_password) { "nuevapassword1234" }

    it "changes the password and destroys the other sessions" do
      other = user.sessions.create!(user_agent: "otro-dispositivo", ip_address: "10.0.0.1")

      patch settings_password_path, params: {
        user: {
          password_challenge: password,
          password: new_password,
          password_confirmation: new_password
        }
      }

      expect(response).to redirect_to(settings_sessions_path)
      expect(flash[:success]).to eq(I18n.t("settings.passwords.update.success"))
      expect(user.reload.authenticate(new_password)).to be_truthy
      expect(Session.exists?(other.id)).to be false
      expect(Session.exists?(current_session.id)).to be true
    end

    it "shows an error and keeps the password when the current one is wrong" do
      patch settings_password_path, params: {
        user: {
          password_challenge: "contrasena-equivocada",
          password: new_password,
          password_confirmation: new_password
        }
      }

      expect(response).to redirect_to(settings_sessions_path)
      expect(flash[:error]).to eq(I18n.t("settings.passwords.update.wrong_current"))
      expect(user.reload.authenticate(password)).to be_truthy
      expect(user.authenticate(new_password)).to be_falsey
    end
  end

  describe "DELETE /settings/sessions/:id" do
    it "destroys another session and it stops authenticating" do
      other = user.sessions.create!(user_agent: "movil", ip_address: "10.0.0.2")

      delete settings_session_path(other)

      expect(response).to redirect_to(settings_sessions_path)
      expect(flash[:success]).to eq(I18n.t("settings.sessions.destroy.success"))
      expect(Session.exists?(other.id)).to be false

      use_session_cookie(other)
      get dashboard_path
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 404 for the current session" do
      delete settings_session_path(current_session)

      expect(response).to have_http_status(:not_found)
      expect(Session.exists?(current_session.id)).to be true
    end

    it "returns 404 for a session of another user" do
      foreign = create(:user, :with_household).sessions.create!(user_agent: "x", ip_address: "10.0.0.3")

      delete settings_session_path(foreign)

      expect(response).to have_http_status(:not_found)
      expect(Session.exists?(foreign.id)).to be true
    end
  end
end
