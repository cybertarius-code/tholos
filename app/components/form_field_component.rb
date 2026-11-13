class FormFieldComponent < ViewComponent::Base
  INPUT_METHODS = {
    text: :text_field,
    email: :email_field,
    password: :password_field,
    number: :number_field
  }.freeze

  def initialize(form:, attribute:, label:, input_type: :text, help_text: nil, error: nil, input_options: {})
    @form = form
    @attribute = attribute
    @label = label
    @help_text = help_text
    @error = error
    @input_method = INPUT_METHODS[input_type.to_sym] || input_type.to_sym
    unless INPUT_METHODS.value?(@input_method)
      raise ArgumentError, "Unknown input type: #{input_type}"
    end
    @input_options = input_options.dup
    @input_id = @input_options[:id] || @form.field_id(@attribute)
  end

  def input_html
    options = @input_options.except(:id, :aria, :class)
    options[:id] = @input_id
    options[:class] = class_names(
      "mt-2 block w-full rounded-md border border-line px-3 py-2 text-base shadow-sm focus:outline-blue-600",
      @input_options[:class]
    )

    aria = (@input_options[:aria] || {}).dup
    described_by = [ aria[:describedby], help_id, error_id ].compact.join(" ")
    aria[:describedby] = described_by if described_by.present?
    aria[:invalid] = true if @error.present?
    options[:aria] = aria if aria.present?

    @form.public_send(@input_method, @attribute, **options)
  end

  def help_id
    "#{@input_id}_help" if @help_text.present?
  end

  def error_id
    "#{@input_id}_error" if @error.present?
  end
end
