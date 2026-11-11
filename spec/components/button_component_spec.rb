require "rails_helper"

RSpec.describe ButtonComponent, type: :component do
  it "renders a button with its content and variant" do
    render_inline(described_class.new(variant: :primary, type: "submit")) { "Guardar" }

    expect(rendered_content).to include("<button")
    expect(rendered_content).to include('type="submit"')
    expect(rendered_content).to include("bg-ink")
    expect(rendered_content).to include("Guardar")
  end

  it "renders links and preserves the disabled state" do
    render_inline(described_class.new(href: "/dashboard", variant: :ghost, disabled: true)) { "Abrir" }

    expect(rendered_content).to include("<a")
    expect(rendered_content).not_to include('href="/dashboard"')
    expect(rendered_content).to include('aria-disabled="true"')
    expect(rendered_content).to include("Abrir")
  end

  it "rejects unknown variants and sizes" do
    expect { described_class.new(variant: :unknown) }.to raise_error(ArgumentError)
    expect { described_class.new(size: :unknown) }.to raise_error(ArgumentError)
  end
end
