require "rails_helper"

RSpec.describe ImportRow do
  let(:account) { create(:account, opening_date: Date.new(2026, 1, 1)) }
  let(:import) { Import.create!(household: account.household, account: account) }

  def build_row(**attributes)
    described_class.new(import: import, line: 1, date: Date.new(2026, 1, 5), concept: "FARMACIA",
                        amount_cents: -240, balance_cents: 1_000, import_ref: "ref", **attributes)
  end

  it "la decisión es omitir, una categoría o nada" do
    category = create(:category, household: account.household)
    row = build_row

    expect(row).to be_undecided
    row.decision = category.id.to_s
    expect(row).to have_attributes(category_id: category.id, skipped: false, decision: category.id.to_s)
    row.decision = "skip"
    expect(row).to have_attributes(category_id: nil, skipped: true, decision: "skip")
  end

  it "no admite categorías de otro hogar ni archivadas" do
    expect(build_row(category: create(:category))).not_to be_valid
    expect(build_row(category: create(:category, :archived, household: account.household))).not_to be_valid
  end

  it "el importe se corrige con coma y signo, y no puede ser cero" do
    expect(build_row(amount_input: "-1.234,56").amount_cents).to eq(-123_456)
    expect(build_row(amount_input: "0")).not_to be_valid
    expect(build_row(amount_input: "dos")).not_to be_valid
  end

  it "las anteriores al corte, las duplicadas y las de una importación confirmada no se pueden cambiar" do
    expect(build_row).not_to be_locked
    expect(build_row(proposal: "before_cutoff")).to be_locked
    expect(build_row(proposal: "duplicate")).to be_locked
    import.confirmed!
    expect(build_row).to be_locked
  end
end
