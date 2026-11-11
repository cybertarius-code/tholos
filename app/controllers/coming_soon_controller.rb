class ComingSoonController < ApplicationController
  SECTIONS = %w[ movements accounts budget goals net_worth settings ].freeze

  def show
    @section = params[:section]
    head :not_found unless SECTIONS.include?(@section)
  end
end
