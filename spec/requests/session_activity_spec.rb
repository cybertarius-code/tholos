require "rails_helper"

RSpec.describe "Session activity", type: :request do
  let(:user) { create(:user, :with_household) }

  it "updates last use at most once per hour" do
    current = sign_in_as(user)

    get dashboard_path
    expect { get dashboard_path }.not_to change { current.reload.updated_at }

    travel 2.hours do
      expect { get dashboard_path }.to change { current.reload.updated_at }
    end
  end
end
