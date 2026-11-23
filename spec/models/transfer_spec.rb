require "rails_helper"

RSpec.describe Transfer do
  let(:household) { create(:household) }
  let(:checking) { create(:account, household: household, name: "Corriente BBVA", opening_balance_cents: 100_000) }
  let(:savings) { create(:account, household: household, name: "Ahorro", kind: "savings") }
  let(:date) { Date.new(2026, 11, 20) }

  def record(from: checking, to: savings, amount_cents: 30_000, **options)
    described_class.record!(household: household, from: from, to: to, amount_cents: amount_cents, date: date, **options)
  end

  def form(from: checking, to: savings, amount_input: "300", **attributes)
    household.transfers.new(from_account_id: from&.id, to_account_id: to&.id, amount_input: amount_input,
                            date: date.iso8601, **attributes)
  end

  def expect_nothing_saved
    expect(described_class.count).to eq(0)
    expect(Transaction.count).to eq(0)
  end

  describe ".record!" do
    it "crea una salida y una entrada opuestas, con la misma fecha y sin categoría" do
      transfer = record(notes: "Ahorro de noviembre")

      expect(transfer.outflow).to have_attributes(account_id: checking.id, amount_cents: -30_000, date: date,
                                                  category_id: nil, currency: "EUR", notes: "Ahorro de noviembre")
      expect(transfer.inflow).to have_attributes(account_id: savings.id, amount_cents: 30_000, date: date,
                                                 category_id: nil, currency: "EUR", notes: "Ahorro de noviembre")
      expect(Transaction.where(transfer_id: transfer.id).count).to eq(2)
    end

    it "no cuenta como ingreso ni como gasto, y el total de las cuentas no cambia" do
      record

      expect(Transaction.income_and_expense).to be_empty
      expect(checking.balance_cents(on: date) + savings.balance_cents(on: date)).to eq(100_000)
    end

    it "salda la tarjeta: Visa a -450 € recibe 450 € y queda a 0 €" do
      visa = create(:account, :credit_card, household: household, name: "Visa", opening_balance_cents: -45_000)

      record(to: visa, amount_cents: 45_000)

      expect(visa.balance_cents(on: date)).to eq(0)
      expect(checking.balance_cents(on: date)).to eq(55_000)
    end

    it "lanza RecordInvalid y no guarda nada si los datos no valen" do
      expect { record(to: checking) }.to raise_error(ActiveRecord::RecordInvalid)
      expect_nothing_saved
    end
  end

  describe "restricciones" do
    it "rechaza la misma cuenta en los dos lados" do
      transfer = form(to: checking)

      expect(transfer.save).to be(false)
      expect(transfer.errors).to be_added(:to_account_id, :same_as_from)
      expect_nothing_saved
    end

    it "rechaza cuentas de monedas distintas (F1)" do
      dollars = create(:account, household: household, currency: "USD")
      transfer = form(to: dollars)

      expect(transfer.save).to be(false)
      expect(transfer.errors).to be_added(:to_account_id, :currency_mismatch)
      expect_nothing_saved
    end

    it "rechaza una cuenta cerrada como origen o como destino" do
      closed = create(:account, :closed, household: household)

      [ form(from: closed), form(to: closed) ].each do |transfer|
        expect(transfer.save).to be(false)
      end
      expect(form(from: closed).tap(&:validate).errors).to be_added(:from_account_id, :closed)
      expect(form(to: closed).tap(&:validate).errors).to be_added(:to_account_id, :closed)
      expect_nothing_saved
    end

    it "rechaza una cuenta de otro hogar" do
      foreign = create(:account)
      transfer = form(to: foreign)

      expect(transfer.save).to be(false)
      expect(transfer.errors).to be_added(:to_account_id, :invalid)
      expect_nothing_saved
    end

    it "exige cuentas, fecha e importe mayor que cero" do
      transfer = household.transfers.new(amount_input: "0")

      expect(transfer.save).to be(false)
      expect(transfer.errors).to be_added(:from_account_id, :blank)
      expect(transfer.errors).to be_added(:to_account_id, :blank)
      expect(transfer.errors).to be_added(:date, :blank)
      expect(transfer.errors).to be_added(:amount, :must_be_positive)
    end

    it "lee el importe en formato español y nunca lo guarda negativo" do
      expect(form(amount_input: "1.234,56").tap(&:save!).inflow.amount_cents).to eq(123_456)
      expect(form(amount_input: "-5").tap(&:save!).outflow.amount_cents).to eq(-500)
      expect(form(amount_input: "abc").tap(&:validate).errors).to be_added(:amount, :not_a_number)
    end
  end

  describe "atomicidad" do
    it "si falla el segundo lado no se guarda ninguno, tampoco la transferencia" do
      inserts = 0
      allow_any_instance_of(Transaction).to receive(:_create_record).and_wrap_original do |original, *args|
        inserts += 1
        raise ActiveRecord::StatementInvalid, "fallo forzado en el segundo lado" if inserts == 2

        original.call(*args)
      end

      expect { record }.to raise_error(ActiveRecord::StatementInvalid, /segundo lado/)
      expect(inserts).to eq(2)
      expect_nothing_saved
    end
  end

  describe "editar" do
    let!(:transfer) { record }

    def reload_transfer
      described_class.includes(:legs).find(transfer.id)
    end

    it "actualiza los dos lados a la vez: importe, fecha, cuentas y notas" do
      wallet = create(:account, household: household, kind: "cash")
      edited = reload_transfer

      expect(edited.update(amount_input: "50,25", date: "2026-11-21", to_account_id: wallet.id, notes: "Cajero")).to be(true)

      expect(reload_transfer.legs.map { |leg| [ leg.account_id, leg.amount_cents, leg.date, leg.notes ] })
        .to contain_exactly([ checking.id, -5_025, Date.new(2026, 11, 21), "Cajero" ],
                            [ wallet.id, 5_025, Date.new(2026, 11, 21), "Cajero" ])
    end

    it "si la edición no vale, no cambia ningún lado" do
      expect(reload_transfer.update(to_account_id: checking.id, amount_input: "1")).to be(false)

      expect(Transaction.where(transfer_id: transfer.id).pluck(:amount_cents)).to contain_exactly(-30_000, 30_000)
    end

    it "permite editar una transferencia antigua aunque una de sus cuentas ya esté cerrada" do
      savings.update!(status: "closed")

      expect(reload_transfer.update(notes: "Antigua")).to be(true)
      expect(reload_transfer.inflow.notes).to eq("Antigua")
    end

    it "no deja un lado con categoría" do
      leg = Transaction.find(transfer.inflow.id)
      leg.category_id = create(:category, household: household).id

      expect(leg.save).to be(false)
      expect(leg.errors).to be_added(:base, :un_solo_tipo)
    end
  end

  describe "borrar" do
    let!(:transfer) { record }

    it "borrar cualquiera de los dos lados borra los dos y la transferencia" do
      [ :outflow, :inflow ].each do |side|
        transfer = record
        leg = Transaction.find(transfer.public_send(side).id)

        expect(leg.destroy).to be_truthy
        expect(leg).to be_destroyed
        expect(Transaction.where(transfer_id: transfer.id)).to be_empty
        expect(described_class.exists?(transfer.id)).to be(false)
      end
    end

    it "borrar la transferencia borra sus dos lados" do
      described_class.includes(:legs).find(transfer.id).destroy!

      expect_nothing_saved
    end

    it "un movimiento normal se sigue borrando solo" do
      expense = create(:transaction, account: checking)

      expense.destroy!

      expect(Transaction.where(transfer_id: transfer.id).count).to eq(2)
    end
  end

  it "#counterpart_of da el otro lado" do
    transfer = described_class.includes(:legs).find(record.id)

    expect(transfer.counterpart_of(transfer.outflow)).to eq(transfer.inflow)
    expect(transfer.counterpart_of(transfer.inflow)).to eq(transfer.outflow)
  end
end
