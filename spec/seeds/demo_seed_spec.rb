require "rails_helper"

RSpec.describe "db:seed" do
  def run_seeds
    load Rails.root.join("db/seeds.rb")
  end

  it "es idempotente: dos ejecuciones dejan un único usuario, hogar y membresía" do
    run_seeds
    run_seeds

    user = User.find_by!(email_address: "demo@tholos.local")
    expect(User.where(email_address: "demo@tholos.local").count).to eq(1)
    expect(user.households.count).to eq(1)
    expect(user.memberships.count).to eq(1)
    expect(Household.count).to eq(1)
    expect(Membership.count).to eq(1)
  end

  it "el usuario demo puede iniciar sesión con la contraseña local" do
    run_seeds

    user = User.find_by!(email_address: "demo@tholos.local")
    expect(user.authenticate("tholos-demo-local")).to be_truthy
  end

  it "aborta con un mensaje claro cuando Rails.env es producción" do
    allow(Rails.env).to receive(:production?).and_return(true)

    expect { run_seeds }
      .to output(/no se ejecutan en producción/).to_stderr
      .and raise_error(SystemExit)
  end
end
