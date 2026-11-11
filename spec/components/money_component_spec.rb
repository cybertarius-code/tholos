require "rails_helper"

RSpec.describe MoneyComponent, type: :component do
  it "formats expenses in Spanish with a typographic minus sign" do
    render_inline(described_class.new(cents: -123_450, currency: "EUR"))

    expect(rendered_content).to include("−1.234,50 €")
    expect(rendered_content).to include("text-expense")
    expect(rendered_content).to include("tabular-nums")
  end

  it "uses the income class for positive values" do
    render_inline(described_class.new(cents: 123_450, currency: "EUR"))

    expect(rendered_content).to include("text-income")
  end
end
