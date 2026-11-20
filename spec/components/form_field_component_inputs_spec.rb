require "rails_helper"

RSpec.describe FormFieldComponent, "select, checkbox and label options", type: :component do
  let(:form) { ActionView::Helpers::FormBuilder.new(:category, Category.new, vc_test_controller.view_context, {}) }

  it "renders a select with its choices" do
    render_inline(described_class.new(form: form, attribute: :kind, label: "Tipo", input_type: :select,
                                      choices: [ [ "Gasto", "expense" ], [ "Ingreso", "income" ] ]))

    expect(page).to have_select("Tipo", options: %w[ Gasto Ingreso ])
  end

  it "requires choices for a select" do
    expect { described_class.new(form: form, attribute: :kind, label: "Tipo", input_type: :select) }
      .to raise_error(ArgumentError, /choices/)
  end

  it "renders a checkbox with its label" do
    render_inline(described_class.new(form: form, attribute: :name, label: "Activa", input_type: :checkbox))

    expect(page).to have_field("Activa", type: "checkbox")
  end

  it "passes label options to the label" do
    render_inline(described_class.new(form: form, attribute: :name, label: "Nombre",
                                      label_options: { data: { test: "x" } }))

    expect(page).to have_css('label[data-test="x"]', text: "Nombre")
  end
end
