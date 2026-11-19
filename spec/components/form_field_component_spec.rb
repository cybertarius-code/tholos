require "rails_helper"

RSpec.describe FormFieldComponent, type: :component do
  it "associates help and error text with an invalid input" do
    form = ActionView::Helpers::FormBuilder.new(:user, User.new, vc_test_controller.view_context, {})

    render_inline(described_class.new(
      form: form,
      attribute: :email_address,
      label: "Correo electrónico",
      input_type: :email,
      help_text: "Usaremos esta dirección para iniciar sesión.",
      error: "No es válido."
    ))

    expect(rendered_content).to include('for="user_email_address"')
    expect(rendered_content).to include('id="user_email_address"')
    expect(rendered_content).to include('aria-describedby="user_email_address_help user_email_address_error"')
    expect(rendered_content).to include('aria-invalid="true"')
    expect(rendered_content).to include("No es válido.")
  end
end

RSpec.describe FormFieldComponent, "other input types", type: :component do
  let(:form) { ActionView::Helpers::FormBuilder.new(:account, Account.new, vc_test_controller.view_context, {}) }

  it "renders a select with its choices" do
    render_inline(described_class.new(form: form, attribute: :kind, label: "Tipo", input_type: :select,
                                      choices: [ [ "Corriente", "checking" ], [ "Ahorro", "savings" ] ]))

    expect(page).to have_select("Tipo", options: %w[Corriente Ahorro])
  end

  it "requires choices for a select" do
    expect { described_class.new(form: form, attribute: :kind, label: "Tipo", input_type: :select) }
      .to raise_error(ArgumentError, /choices/)
  end

  it "renders a checkbox with its label after the input" do
    render_inline(described_class.new(form: form, attribute: :include_in_net_worth, label: "Patrimonio", input_type: :checkbox))

    expect(page).to have_field("Patrimonio", type: "checkbox")
  end

  it "passes label options to the label" do
    render_inline(described_class.new(form: form, attribute: :opening_amount, label: "Saldo", input_type: :number,
                                      label_options: { data: { account_form_target: "amountLabel" } }))

    expect(page).to have_css('label[data-account-form-target="amountLabel"]', text: "Saldo")
  end
end
