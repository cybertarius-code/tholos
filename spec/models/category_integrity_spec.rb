require "rails_helper"

RSpec.describe Category, "database integrity" do
  let(:household) { create(:household) }
  let(:transport) { create(:category, household: household, name: "Transporte") }
  let(:salary) { create(:category, :income, household: household, name: "Nómina") }
  let!(:fuel) { create(:category, :child, household: household, parent: transport, name: "Gasolina") }

  describe "FK compuesta (parent_id, kind)" do
    it "impide que una hija tenga un tipo distinto del padre" do
      expect { fuel.update_column(:kind, "income") }
        .to raise_error(ActiveRecord::InvalidForeignKey, /categories_parent_kind_fk/)
    end

    it "impide mover una hija a un padre de otro tipo" do
      expect { fuel.update_column(:parent_id, salary.id) }
        .to raise_error(ActiveRecord::InvalidForeignKey, /categories_parent_kind_fk/)
    end

    it "impide cambiar el tipo de un padre con hijas" do
      expect { transport.update_column(:kind, "income") }
        .to raise_error(ActiveRecord::InvalidForeignKey, /categories_parent_kind_fk/)
    end

    it "impide borrar un padre con hijas (ON DELETE RESTRICT)" do
      expect { described_class.where(id: transport.id).delete_all }
        .to raise_error(ActiveRecord::StatementInvalid, /PG::RestrictViolation/)
    end
  end

  describe "índice único (household_id, parent_id, lower(name)) con NULLS NOT DISTINCT" do
    it "rechaza dos padres con el mismo nombre en distinta caja" do
      expect { described_class.insert!(transport.attributes.except("id").merge("name" => "TRANSPORTE")) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "rechaza dos hijas con el mismo nombre bajo el mismo padre" do
      expect { described_class.insert!(fuel.attributes.except("id").merge("name" => "gasolina")) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "CHECK" do
    it "rechaza un grupo en una hija" do
      expect { fuel.update_column(:report_group, "essentials") }
        .to raise_error(ActiveRecord::CheckViolation, /categories_report_group_only_on_parents/)
    end

    it "rechaza un tipo fuera del enum" do
      expect { salary.update_column(:kind, "transfer") }
        .to raise_error(ActiveRecord::CheckViolation, /categories_kind_check/)
    end

    it "rechaza un grupo fuera del enum" do
      expect { transport.update_column(:report_group, "savings") }
        .to raise_error(ActiveRecord::CheckViolation, /categories_report_group_check/)
    end
  end

  describe "violaciones convertidas en errores de validación (ADR-0014 A)" do
    it "save devuelve false con el error traducido aunque se salten las validaciones" do
      duplicate = build(:category, household: household, name: "transporte")

      expect(duplicate.save(validate: false)).to be(false)
      expect(duplicate.errors).to be_added(:name, :taken)
      expect(duplicate).to be_new_record
    end

    it "save! lanza RecordInvalid" do
      duplicate = build(:category, household: household, name: "transporte")

      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "convierte la FK compuesta en un error del padre" do
      moved = described_class.find(fuel.id)
      moved.parent_id = salary.id

      expect(moved.save(validate: false)).to be(false)
      expect(moved.errors).to be_added(:parent_id, :kind_mismatch)
    end

    it "deja usable la transacción exterior" do
      described_class.transaction do
        build(:category, household: household, name: "transporte").save(validate: false)

        # Sin el savepoint, esta consulta fallaría con "current transaction is aborted"
        expect(described_class.where(household: household).count).to eq(2)
      end
    end

    it "vuelve a lanzar las restricciones sin traducción" do
      orphan = build(:category, household: household)
      orphan.household_id = 0

      expect { orphan.save(validate: false) }.to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end
end
