require "rails_helper"

RSpec.describe Household, "#seed_default_categories!" do
  let(:household) { create(:household) }

  it "crea los padres de gasto con su grupo y los de ingreso, sin hijas" do
    expect(household.seed_default_categories!).to eq(23)

    transport = household.categories.find_by!(name: "Transporte")
    expect(transport).to have_attributes(kind: "expense", report_group: "essentials", parent_id: nil)
    expect(household.categories.find_by!(name: "Comisiones bancarias").report_group).to eq("finance")
    expect(household.categories.find_by!(name: "Nómina")).to have_attributes(kind: "income", report_group: nil)
    expect(household.categories.where.not(parent_id: nil)).to be_empty
  end

  it "conserva el orden de la lista" do
    household.seed_default_categories!

    expect(household.categories.expense.ordered.limit(3).pluck(:name))
      .to eq([ "Alimentación", "Vivienda y suministros", "Hogar y familia" ])
  end

  it "es idempotente y respeta lo que el usuario ya tiene (también archivado o renombrado en caja)" do
    create(:category, household: household, name: "transporte", report_group: "lifestyle")
    create(:category, :income, :archived, household: household, name: "Nómina")

    expect(household.seed_default_categories!).to eq(21)
    expect(household.seed_default_categories!).to eq(0)
    expect(household.categories.count).to eq(23)
  end

  it "todas las entradas del YAML son válidas" do
    described_class.default_categories.each do |attributes|
      expect(household.categories.build(attributes)).to be_valid, attributes[:name]
    end
  end
end

RSpec.describe User, ".create_with_household!" do
  it "da al hogar nuevo sus categorías por defecto" do
    user = described_class.create_with_household!(email: "ana@example.com", password: "password1234")
    household = Household.joins(:memberships).find_by!(memberships: { user_id: user.id })

    expect(household.categories.count).to eq(23)
  end
end
