require "rails_helper"

RSpec.describe "Formatos localizados (es)" do
  around { |example| I18n.with_locale(:es) { example.run } }

  it "formatea fechas cortas como '28 oct 2026'" do
    expect(I18n.l(Date.new(2026, 10, 28), format: :short)).to eq("28 oct 2026")
  end

  it "formatea números con punto de miles y coma decimal" do
    expect(ActiveSupport::NumberHelper.number_to_rounded(1234.5, precision: 2)).to eq("1.234,50")
  end
end
