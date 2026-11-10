require "rails_helper"

RSpec.describe "Traducciones ausentes en vistas", type: :view do
  it "hace fallar el render si una vista usa una clave inexistente" do
    expect {
      render inline: '<%= t("clave.que.no.existe") %>'
    }.to raise_error(ActionView::Template::Error, /Translation missing/)
  end

  it "renderiza con normalidad cuando la clave existe" do
    render inline: '<%= t("shared.sign_out") %>'
    expect(rendered).to include("Cerrar sesión")
  end
end
