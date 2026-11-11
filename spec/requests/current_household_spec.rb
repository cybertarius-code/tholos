require "rails_helper"

RSpec.describe "Current.household", type: :request do
  let(:user)      { create(:user, password: "password1234") }
  let(:household) { create(:household, name: "Casa Tholos") }

  context "con sesión iniciada y una membresía" do
    before do
      create(:membership, user: user, household: household)
      sign_in_as(user)
    end

    it "es el hogar del usuario" do
      get dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Casa Tholos")
    end
  end

  # El spec de "household_id ajeno en la sesión" vuelve en F7, con el endpoint del selector de hogar

  context "sin sesión" do
    it "no asigna hogar y redirige al login" do
      # `/` es pública (US-0003); se prueba con una ruta protegida
      get dashboard_path

      expect(response).to redirect_to(new_session_path)
    end
  end

  context "con sesión pero sin membresía" do
    before { sign_in_as(user) }

    it "falla con un error explícito (404) en vez de navegar sin hogar" do
      get dashboard_path

      expect(response).to have_http_status(:not_found)
    end
  end
end
