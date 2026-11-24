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

  describe "transferencia y ya registrado (US-0114)" do
    let(:household) { account.household }

    it "la decisión puede ser una transferencia o un movimiento ya registrado, y solo una" do
      savings = create(:account, household: household)
      movement = create(:transaction, account: account, amount_cents: -240, date: Date.new(2026, 1, 5))
      row = build_row(decision: "transfer:#{savings.id}")

      expect(row).to have_attributes(counter_account_id: savings.id, category_id: nil, decision: "transfer:#{savings.id}")
      expect(row).to be_transfer
      row.decision = "recorded:#{movement.id}"
      expect(row).to have_attributes(counter_account_id: nil, matched_transaction_id: movement.id)
      expect(row).to be_valid
      row.decision = ""
      expect(row).to be_undecided
    end

    it "la BD no admite dos decisiones a la vez" do
      row = build_row(decision: "transfer:#{create(:account, household: household).id}")
      row.save!

      expect(row.update(category_id: create(:category, household: household).id)).to be(false)
      expect(row.errors).to include(:decision)
    end

    it "la cuenta de la transferencia: activa, del hogar, de la misma moneda y distinta de la importada" do
      expect(build_row(decision: "transfer:#{create(:account, household: household).id}")).to be_valid
      expect(build_row(decision: "transfer:#{create(:account, household: household, currency: "USD").id}").tap(&:valid?).errors[:counter_account_id]).to eq([ "tiene otra moneda" ])
      expect(build_row(decision: "transfer:#{create(:account, :closed, household: household).id}").tap(&:valid?).errors[:counter_account_id]).to eq([ "está cerrada" ])
      expect(build_row(decision: "transfer:#{create(:account).id}")).not_to be_valid
      expect(build_row(decision: "transfer:#{account.id}")).not_to be_valid
    end

    it "ya registrado: de esta cuenta, mismo importe, sin huella y a ± 7 días" do
      matching = ->(**attributes) { create(:transaction, account: account, amount_cents: -240, date: Date.new(2026, 1, 12), **attributes) }

      expect(build_row(decision: "recorded:#{matching.call.id}")).to be_valid
      expect(build_row(decision: "recorded:#{matching.call(date: Date.new(2026, 1, 13)).id}")).not_to be_valid
      expect(build_row(decision: "recorded:#{matching.call(amount_cents: -241).id}")).not_to be_valid
      expect(build_row(decision: "recorded:#{matching.call(import_ref: "otra").id}")).not_to be_valid
      expect(build_row(decision: "recorded:#{create(:transaction, amount_cents: -240, date: Date.new(2026, 1, 5)).id}")).not_to be_valid
    end
  end
end
