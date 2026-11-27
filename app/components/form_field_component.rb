class FormFieldComponent < ViewComponent::Base
  INPUT_METHODS = {
    text: :text_field,
    email: :email_field,
    password: :password_field,
    number: :number_field,
    date: :date_field,
    select: :select,
    text_area: :text_area,
    checkbox: :check_box,
    file: :file_field
  }.freeze

  INPUT_CLASSES = "mt-2 block w-full rounded-md border border-line bg-surface px-3 py-2 text-base text-ink shadow-sm focus:outline-blue-600".freeze
  FILE_CLASSES = "mt-2 block w-full text-base text-ink file:mr-3 file:min-h-11 file:rounded-md file:border file:border-line file:bg-surface file:px-3 file:text-sm file:font-medium file:text-ink".freeze
  CHECKBOX_CLASSES = "size-5 rounded border-line text-ink focus:outline-blue-600".freeze

  def initialize(form:, attribute:, label:, input_type: :text, help_text: nil, error: nil, choices: nil, input_options: {}, label_options: {})
    @form = form
    @attribute = attribute
    @label = label
    @help_text = help_text
    @error = error
    @choices = choices
    @input_method = INPUT_METHODS[input_type.to_sym] || input_type.to_sym
    unless INPUT_METHODS.value?(@input_method)
      raise ArgumentError, "Unknown input type: #{input_type}"
    end
    raise ArgumentError, "Provide choices for a select" if select? && choices.nil?

    @input_options = input_options.dup
    @label_options = label_options
    @input_id = @input_options[:id] || @form.field_id(@attribute)
  end

  def checkbox?
    @input_method == :check_box
  end

  def label_html
    classes = checkbox? ? "text-sm font-medium text-ink" : "block text-sm font-medium text-ink"
    @form.label @attribute, @label, **@label_options, for: @input_id, class: classes
  end

  def input_html
    options = @input_options.except(:id, :aria, :class)
    options[:id] = @input_id
    options[:class] = class_names(base_classes, @input_options[:class])

    aria = (@input_options[:aria] || {}).dup
    described_by = [ aria[:describedby], help_id, error_id ].compact.join(" ")
    aria[:describedby] = described_by if described_by.present?
    aria[:invalid] = true if @error.present?
    options[:aria] = aria if aria.present?

    if select?
      @form.select(@attribute, @choices, {}, options)
    else
      @form.public_send(@input_method, @attribute, **options)
    end
  end

  def help_id
    "#{@input_id}_help" if @help_text.present?
  end

  def error_id
    "#{@input_id}_error" if @error.present?
  end

  private
    def base_classes
      return CHECKBOX_CLASSES if checkbox?
      return FILE_CLASSES if @input_method == :file_field

      INPUT_CLASSES
    end

    def select?
      @input_method == :select
    end
end
