require "rails_helper"

RSpec.describe CategoryIconComponent, type: :component do
  it "renders the emoji, decorative, with the palette ring" do
    render_inline(described_class.new(color: "teal", icon: "car"))

    expect(page).to have_css('span[aria-hidden="true"].ring-cat-teal', text: "🚗")
  end

  it "falls back to a neutral tag for unknown values" do
    render_inline(described_class.new(color: "pink", icon: "unicorn"))

    expect(page).to have_css("span.ring-cat-slate", text: "🏷️")
  end
end
