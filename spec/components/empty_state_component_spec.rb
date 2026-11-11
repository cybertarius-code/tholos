require "rails_helper"

RSpec.describe EmptyStateComponent, type: :component do
  it "renders an icon, title, and explanatory text" do
    render_inline(described_class.new(icon: "○", title: "Sin movimientos", text: "Aún no hay datos."))

    expect(rendered_content).to include("○")
    expect(rendered_content).to include("Sin movimientos")
    expect(rendered_content).to include("Aún no hay datos.")
    expect(rendered_content).not_to include("<a")
  end

  it "renders an optional action" do
    render_inline(described_class.new(
      icon: "+",
      title: "Sin movimientos",
      text: "Aún no hay datos.",
      action_label: "Añadir movimiento",
      action_href: "/movements/new"
    ))

    expect(rendered_content).to include('href="/movements/new"')
    expect(rendered_content).to include("Añadir movimiento")
  end
end
