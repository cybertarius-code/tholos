require "rails_helper"

RSpec.describe BadgeComponent, type: :component do
  it "renders each supported variant" do
    {
      neutral: "bg-stone-100",
      success: "bg-green-50",
      warning: "bg-amber-50",
      error: "bg-red-50"
    }.each do |variant, css_class|
      render_inline(described_class.new(variant: variant)) { variant.to_s }
      expect(rendered_content).to include(css_class)
      expect(rendered_content).to include(variant.to_s)
    end
  end

  it "rejects unknown variants" do
    expect { described_class.new(variant: :unknown) }.to raise_error(ArgumentError)
  end
end
