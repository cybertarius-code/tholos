class MoneyComponent < ViewComponent::Base
  def initialize(cents:, currency: Money.default_currency)
    @money = Money.new(cents, currency)
  end

  def formatted_amount
    I18n.with_locale(:es) do
      @money.format(locale: :es).sub(/\A-/, "−")
    end
  end

  def amount_class
    return "text-expense" if @money.negative?
    return "text-income" if @money.positive?

    "text-ink"
  end
end
