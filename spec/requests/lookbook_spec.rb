require "rails_helper"

RSpec.describe "Lookbook", type: :request do
  it "is unavailable outside development" do
    get "/lookbook"

    expect(response).to have_http_status(:not_found)
  end
end
