module Categories
  class ArchivesController < ApplicationController
    before_action :set_category

    # Archivar (también las hijas)
    def create
      @category.archive!
      redirect_to categories_path, success: t(".success", name: @category.name), status: :see_other
    end

    # Desarchivar
    def destroy
      @category.unarchive!
      redirect_to categories_path, success: t(".success", name: @category.name), status: :see_other
    end

    private
      def set_category
        @category = Current.household.categories.find(params[:category_id])
      end
  end
end
