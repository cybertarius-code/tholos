require "rails_helper"
require "rake"

RSpec.describe "rake users:create" do
  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
  end

  let(:task) { Rake::Task["users:create"] }

  before { task.reenable } # permite ejecutarla en cada ejemplo

  def run_task(*args)
    task.invoke(*args)
  end

  context "con argumentos válidos" do
    it "crea usuario, household y membresía" do
      expect { run_task("ana@example.com", "password1234", "Casa Ana") }
        .to change(User, :count).by(1)
        .and change(Household, :count).by(1)
        .and change(Membership, :count).by(1)
    end

    it "deja al usuario como owner de su hogar" do
      run_task("ana@example.com", "password1234", "Casa Ana")

      user = User.find_by!(email_address: "ana@example.com")
      membership = Membership.includes(:household).find_by!(user: user)

      expect(membership.role).to eq("owner")
      expect(membership.household.name).to eq("Casa Ana")
    end

    it "permite iniciar sesión con la contraseña indicada" do
      run_task("ana@example.com", "password1234", "Casa Ana")

      user = User.find_by!(email_address: "ana@example.com")
      expect(user.authenticate("password1234")).to be_truthy
    end
  end

  context "con argumentos inválidos" do
    it "aborta sin email y no crea nada" do
      expect { expect { run_task(nil, "password1234", "Casa") }.to raise_error(SystemExit) }
        .not_to change { [ User.count, Household.count, Membership.count ] }
    end

    it "no crea duplicados si el email ya existe" do
      create(:user, email_address: "ana@example.com")

      expect { expect { run_task("ana@example.com", "password1234", "Casa") }.to raise_error(SystemExit) }
        .not_to change { [ User.count, Household.count, Membership.count ] }
    end
  end

  context "si falla un paso intermedio" do
    it "no deja registros a medias (transacción)" do
      allow(Membership).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)

      expect { expect { run_task("ana@example.com", "password1234", "Casa") }.to raise_error(StandardError) }
        .not_to change { [ User.count, Household.count ] }
    end
  end
end
