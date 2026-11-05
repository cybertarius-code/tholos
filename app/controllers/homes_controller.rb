class HomesController < ApplicationController
  skip_before_action :require_authentication, only: [ :index ]

  def index; end

  def show; end
end
