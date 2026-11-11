require "rails_helper"

RSpec.describe CardComponent, type: :component do
  it "renders header, body, and footer slots" do
    render_inline(described_class.new) do |card|
      card.with_header { "Resumen" }
      card.with_body { "Contenido" }
      card.with_footer { "Acciones" }
    end

    expect(rendered_content).to include("<header")
    expect(rendered_content).to include("Resumen")
    expect(rendered_content).to include("Contenido")
    expect(rendered_content).to include("<footer")
    expect(rendered_content).to include("Acciones")
  end
end
