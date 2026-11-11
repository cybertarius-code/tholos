class EmptyStateComponent < ViewComponent::Base
  def initialize(icon:, title:, text:, action_label: nil, action_href: nil)
    @icon = icon
    @title = title
    @text = text
    @action_label = action_label
    @action_href = action_href

    if @action_label.present? != @action_href.present?
      raise ArgumentError, "Provide both action_label and action_href"
    end
  end
end
