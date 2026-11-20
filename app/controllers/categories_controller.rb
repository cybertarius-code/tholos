class CategoriesController < ApplicationController
  before_action :set_category, only: %i[ edit update destroy ]

  def index
    # Una sola consulta; el árbol se arma en memoria (sin asociaciones perezosas)
    categories = Current.household.categories.ordered.to_a
    active, @archived = categories.partition { |category| !category.archived? }
    @roots = active.select(&:root?).group_by(&:kind)
    @children = active.reject(&:root?).group_by(&:parent_id)
    @names = categories.index_by(&:id)
  end

  def new
    @category = Current.household.categories.new(color: Category::COLORS.last, icon: "tag", kind: new_kind)

    if params[:parent_id].present?
      parent = Current.household.categories.active.roots.find(params[:parent_id])
      @category.assign_attributes(parent: parent, kind: parent.kind, color: parent.color, icon: parent.icon)
    end
  end

  def create
    @category = Current.household.categories.new(category_params)

    if @category.save
      redirect_to categories_path, success: t(".success", name: @category.name)
    else
      @archived_namesake = @category.archived_namesake
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @category.update(category_params)
      redirect_to categories_path, success: t(".success", name: @category.name)
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @category.destroy
      redirect_to categories_path, success: t(".success", name: @category.name), status: :see_other
    else
      redirect_to edit_category_path(@category), error: t(".in_use"), status: :see_other
    end
  end

  private
    def set_category
      @category = Current.household.categories.find(params[:id])
    end

    def new_kind
      params[:kind].presence_in(Category::KINDS) || "expense"
    end

    def category_params
      params.expect(category: %i[ name kind parent_id report_group color icon ])
    end
end
