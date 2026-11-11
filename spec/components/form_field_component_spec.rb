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
