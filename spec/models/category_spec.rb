require "rails_helper"

RSpec.describe Category do
  let(:household) { create(:household) }
  let(:transport) { create(:category, household: household, name: "Transporte", report_group: "essentials") }
  let(:salary) { create(:category, :income, household: household, name: "Nómina") }

  def build_child(parent, **attributes)
    build(:category, household: household, parent: parent, report_group: nil, **attributes)
  end

  describe "hijas" do
    it "hereda el tipo del padre y usa su grupo, sin guardar uno propio" do
      fuel = build_child(transport, name: "Gasolina", kind: "income", report_group: "lifestyle")

      expect(fuel.save).to be(true)
      expect(fuel).to have_attributes(kind: "expense", report_group: nil, parent_id: transport.id)
    end

    it "no admite un tercer nivel" do
      fuel = create(:category, :child, household: household, parent: transport, name: "Gasolina")
      diesel = build_child(fuel, name: "Diésel")

      expect(diesel).not_to be_valid
      expect(diesel.errors).to be_added(:parent_id, :too_deep)
    end

    it "no deja que un padre con hijas pase a ser hija" do
      create(:category, :child, household: household, parent: transport, name: "Gasolina")
      leisure = create(:category, household: household, name: "Ocio")
      transport_again = described_class.find(transport.id)

      expect(transport_again.update(parent_id: leisure.id)).to be(false)
      expect(transport_again.errors).to be_added(:parent_id, :has_children)
    end

    it "no acepta un padre de otro hogar" do
      foreign = create(:category, name: "Ajena")
      child = build_child(foreign, name: "Hija")

      expect(child).not_to be_valid
      expect(child.errors).to be_added(:parent_id, :invalid)
    end

    it "no acepta un padre archivado" do
      transport.archive!
      child = build_child(described_class.find(transport.id), name: "Gasolina")

      expect(child).not_to be_valid
      expect(child.errors).to be_added(:parent_id, :archived)
    end
  end

  describe "mover una hija" do
    let!(:fuel) { create(:category, :child, household: household, parent: transport, name: "Gasolina") }

    it "se mueve a otro padre de gasto" do
      car = create(:category, household: household, name: "Coche")
      reloaded = described_class.find(fuel.id)

      expect(reloaded.update(parent_id: car.id)).to be(true)
      expect(reloaded.reload.parent_id).to eq(car.id)
    end

    it "no se mueve a un padre de ingreso" do
      reloaded = described_class.find(fuel.id)

      expect(reloaded.update(parent_id: salary.id)).to be(false)
      expect(reloaded.errors).to be_added(:parent_id, :kind_mismatch)
      expect(reloaded.reload.parent_id).to eq(transport.id)
    end
  end

  describe "nombres" do
    it "son únicos en el mismo nivel sin distinguir mayúsculas, también entre padres (parent_id nulo)" do
      create(:category, household: household, name: "Ocio")
      duplicate = build(:category, household: household, name: "  ocio ")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors).to be_added(:name, :taken, value: "ocio")
    end

    it "se pueden repetir en niveles distintos y en otros hogares" do
      create(:category, :child, household: household, parent: transport, name: "Varios")

      expect(build(:category, household: household, name: "Varios")).to be_valid
      expect(build(:category, name: "Transporte")).to be_valid
    end

    it "cuentan las archivadas, y se ofrece la archivada para desarchivarla" do
      gym = create(:category, :archived, household: household, name: "Gimnasio")
      duplicate = build(:category, household: household, name: "gimnasio")

      expect(duplicate).not_to be_valid
      expect(duplicate.archived_namesake).to eq(gym)
    end
  end

  describe "grupo de informe" do
    it "es obligatorio en los padres de gasto" do
      category = build(:category, household: household, report_group: nil)

      expect(category).not_to be_valid
      expect(category.errors).to be_added(:report_group, :blank)
    end

    it "se descarta en los padres de ingreso" do
      category = create(:category, :income, household: household, report_group: "lifestyle")

      expect(category.report_group).to be_nil
    end

    it "rechaza un valor fuera de la lista" do
      expect(build(:category, household: household, report_group: "savings")).not_to be_valid
    end
  end

  describe "tipo" do
    it "se puede cambiar en un padre sin hijas ni movimientos" do
      category = described_class.find(create(:category, household: household).id)

      expect(category.update(kind: "income")).to be(true)
    end

    it "queda fijo si la categoría tiene movimientos" do
      category = described_class.find(create(:category, household: household).id)
      allow(category).to receive(:movements?).and_return(true)

      expect(category.update(kind: "income")).to be(false)
      expect(category.errors).to be_added(:kind, :locked)
      expect(category.reload.kind).to eq("expense")
    end

    it "queda fijo si la categoría tiene hijas" do
      create(:category, :child, household: household, parent: transport, name: "Gasolina")
      category = described_class.find(transport.id)

      expect(category.update(kind: "income")).to be(false)
      expect(category.errors).to be_added(:kind, :locked)
    end
  end

  describe "paleta cerrada" do
    it "rechaza colores e iconos fuera de la lista" do
      category = build(:category, household: household, color: "#ff00ff", icon: "unicorn")

      expect(category).not_to be_valid
      expect(category.errors).to include(:color, :icon)
    end
  end

  describe "archivar" do
    it "archiva el padre y sus hijas en cascada, y las deja fuera de las activas" do
      fuel = create(:category, :child, household: household, parent: transport, name: "Gasolina")
      parking = create(:category, :child, household: household, parent: transport, name: "Parking")

      described_class.find(transport.id).archive!

      expect(described_class.where(id: [ transport.id, fuel.id, parking.id ]).archived.count).to eq(3)
      expect(household.categories.active).to be_empty
    end

    it "desarchivar una hija desarchiva también su padre" do
      fuel = create(:category, :child, household: household, parent: transport, name: "Gasolina")
      described_class.find(transport.id).archive!

      described_class.find(fuel.id).unarchive!

      expect(household.categories.active.pluck(:id)).to contain_exactly(transport.id, fuel.id)
    end
  end

  describe "borrar" do
    it "se borra si no tiene hijas ni movimientos" do
      category = create(:category, household: household)

      expect(described_class.find(category.id).destroy).to be_truthy
    end

    it "no se borra si tiene hijas" do
      create(:category, :child, household: household, parent: transport, name: "Gasolina")
      category = described_class.find(transport.id)

      expect(category.destroy).to be(false)
      expect(category.errors[:base]).to be_present
      expect(described_class.exists?(transport.id)).to be(true)
    end

    it "no se borra si tiene movimientos" do
      category = described_class.find(create(:category, household: household).id)
      allow(category).to receive(:movements?).and_return(true)

      expect(category.destroy).to be(false)
      expect(category.errors).to be_added(:base, :has_movements)
    end
  end

  describe "orden" do
    let!(:food) { create(:category, household: household, name: "Alimentación") }
    let!(:home) { create(:category, household: household, name: "Vivienda") }
    let!(:car) { create(:category, household: household, name: "Transporte") }

    def names
      household.categories.roots.expense.ordered.pluck(:name)
    end

    it "añade las nuevas al final de sus hermanas" do
      expect(names).to eq(%w[ Alimentación Vivienda Transporte ])
    end

    it "sube y baja entre hermanas" do
      expect(described_class.find(car.id).move!(:up)).to be(true)
      expect(names).to eq(%w[ Alimentación Transporte Vivienda ])

      expect(described_class.find(food.id).move!(:down)).to be(true)
      expect(names).to eq(%w[ Transporte Alimentación Vivienda ])
    end

    it "no se sale de los extremos" do
      expect(described_class.find(food.id).move!(:up)).to be(false)
      expect(described_class.find(car.id).move!(:down)).to be(false)
      expect(names).to eq(%w[ Alimentación Vivienda Transporte ])
    end

    it "no mezcla padres de distinto tipo ni hijas" do
      create(:category, :income, household: household, name: "Nómina")
      create(:category, :child, household: household, parent: food, name: "Súper")

      described_class.find(car.id).move!(:up)

      expect(names).to eq(%w[ Alimentación Transporte Vivienda ])
    end
  end
end
