module Categories
  class PositionsController < ApplicationController
    # Subir o bajar entre sus hermanas; la lista se refresca con morphing (sin JS propio)
    def update
      category = Current.household.categories.find(params[:category_id])
      category.move!(params.expect(:direction).presence_in(%w[ up down ]) || raise(ActionController::BadRequest))

      redirect_to categories_path, status: :see_other
    end
  end
end
