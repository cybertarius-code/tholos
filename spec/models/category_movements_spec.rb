require "rails_helper"

RSpec.describe Category, "con movimientos reales" do
  let(:household) { create(:household) }
  let(:category) { create(:category, household: household) }

  before { create(:transaction, account: create(:account, household: household), category: category) }

  it "no cambia de tipo" do
    reloaded = described_class.find(category.id)

    expect(reloaded.update(kind: "income")).to be(false)
    expect(reloaded.errors).to be_added(:kind, :locked)
  end

  it "no se borra, pero se archiva y el movimiento la conserva" do
    reloaded = described_class.find(category.id)

    expect(reloaded.destroy).to be(false)
    reloaded.archive!
    expect(Transaction.where(category_id: category.id).count).to eq(1)
  end
end
