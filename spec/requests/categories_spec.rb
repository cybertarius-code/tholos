require "rails_helper"

RSpec.describe "Categories", type: :request do
  let(:user) { create(:user, :with_household) }
  let(:household) { Household.joins(:memberships).find_by!(memberships: { user_id: user.id }) }
  let!(:transport) { create(:category, household: household, name: "Transporte", report_group: "essentials", icon: "car") }

  let(:valid_params) do
    { category: { name: "Ocio", kind: "expense", parent_id: "", report_group: "lifestyle", color: "plum", icon: "leisure" } }
  end

  context "sin sesión" do
    it "redirige al login" do
      get categories_path

      expect(response).to redirect_to(new_session_path)
    end
  end

  context "con sesión" do
    before { sign_in_as(user) }

    describe "GET /ajustes/categorias" do
      it "muestra el árbol por tipo, con hijas y archivadas plegadas, sin las de otro hogar" do
        create(:category, :child, household: household, parent: transport, name: "Gasolina")
        create(:category, :income, household: household, name: "Nómina")
        create(:category, :archived, household: household, name: "Gimnasio")
        create(:category, name: "Ajena")

        get categories_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Transporte", "Gasolina", "Nómina", "Esenciales")
        expect(response.body).to include(I18n.t("categories.index.archived", count: 1), "Gimnasio")
        expect(response.body).not_to include("Ajena")
      end

      it "hace un número fijo de consultas, sin N+1" do
        get categories_path # calentamiento
        count_queries = lambda do
          queries = 0
          counter = ->(*, payload) { queries += 1 unless payload[:name].in?(%w[ SCHEMA TRANSACTION ]) }
          ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get categories_path }
          queries
        end

        few = count_queries.call
        5.times { |i| create(:category, :child, household: household, parent: transport, name: "Hija #{i}") }
        3.times { |i| create(:category, :archived, household: household, name: "Archivada #{i}") }

        expect(count_queries.call).to eq(few)
      end
    end

    describe "GET /ajustes/categorias/nueva" do
      it "prepara una hija con el tipo de su padre" do
        get new_category_path(parent_id: transport.id)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("categories.new.title_child"))
        expect(response.body).to match(/<option selected="selected" value="#{transport.id}">Transporte/)
      end

      it "devuelve 404 con un padre de otro hogar" do
        get new_category_path(parent_id: create(:category).id)

        expect(response).to have_http_status(:not_found)
      end
    end

    describe "POST /ajustes/categorias" do
      it "crea un padre de gasto" do
        expect { post categories_path, params: valid_params }.to change(household.categories, :count).by(1)

        expect(response).to redirect_to(categories_path)
        expect(household.categories.find_by!(name: "Ocio")).to have_attributes(kind: "expense", report_group: "lifestyle")
      end

      it "crea una hija que hereda el tipo y el grupo de su padre" do
        post categories_path, params: { category: { name: "Gasolina", kind: "income", parent_id: transport.id,
                                                    report_group: "lifestyle", color: "red", icon: "car" } }

        fuel = household.categories.find_by!(name: "Gasolina")
        expect(fuel).to have_attributes(parent_id: transport.id, kind: "expense", report_group: nil)
      end

      it "no crea una categoría dentro de una hija" do
        fuel = create(:category, :child, household: household, parent: transport, name: "Gasolina")

        expect {
          post categories_path, params: valid_params.deep_merge(category: { name: "Diésel", parent_id: fuel.id })
        }.not_to change(Category, :count)
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include(I18n.t("activerecord.errors.models.category.attributes.parent_id.too_deep"))
      end

      it "no crea un padre con un nombre repetido en otra caja" do
        create(:category, household: household, name: "Ocio")

        expect { post categories_path, params: valid_params.deep_merge(category: { name: "ocio" }) }
          .not_to change(Category, :count)
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "ofrece desarchivar la categoría archivada con el mismo nombre" do
        gym = create(:category, :archived, household: household, name: "Gimnasio")

        post categories_path, params: valid_params.deep_merge(category: { name: "gimnasio" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include(I18n.t("categories.new.unarchive", name: "Gimnasio"))
        expect(response.body).to include(%(action="#{category_archive_path(gym)}"))
      end

      it "ignora un household_id en los parámetros" do
        foreign = create(:household)

        post categories_path, params: valid_params.deep_merge(category: { household_id: foreign.id })

        expect(foreign.categories).to be_empty
      end
    end

    describe "PATCH /ajustes/categorias/:id" do
      let!(:fuel) { create(:category, :child, household: household, parent: transport, name: "Gasolina") }

      it "mueve una hija a otro padre de gasto" do
        car = create(:category, household: household, name: "Coche")

        patch category_path(fuel), params: { category: { parent_id: car.id } }

        expect(response).to redirect_to(categories_path)
        expect(fuel.reload.parent_id).to eq(car.id)
      end

      it "no mueve una hija a un padre de ingreso" do
        salary = create(:category, :income, household: household, name: "Nómina")

        patch category_path(fuel), params: { category: { parent_id: salary.id } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(fuel.reload.parent_id).to eq(transport.id)
      end

      it "no cambia el tipo de un padre con hijas" do
        patch category_path(transport), params: { category: { kind: "income" } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(transport.reload.kind).to eq("expense")
      end
    end

    describe "PATCH /ajustes/categorias/:id/posicion" do
      it "sube una categoría por encima de la anterior" do
        food = create(:category, household: household, name: "Alimentación")

        patch category_position_path(food), params: { direction: "up" }

        expect(response).to redirect_to(categories_path)
        expect(household.categories.expense.roots.ordered.pluck(:name)).to eq(%w[ Alimentación Transporte ])
      end

      it "rechaza una dirección desconocida" do
        patch category_position_path(transport), params: { direction: "sideways" }

        expect(response).to have_http_status(:bad_request)
      end
    end

    describe "archivar y desarchivar" do
      it "archiva un padre con sus hijas y lo desarchiva" do
        fuel = create(:category, :child, household: household, parent: transport, name: "Gasolina")

        post category_archive_path(transport)

        expect(response).to redirect_to(categories_path)
        expect(transport.reload.archived_at).to be_present
        expect(fuel.reload.archived_at).to be_present

        delete category_archive_path(transport)

        expect(transport.reload.archived_at).to be_nil
      end
    end

    describe "DELETE /ajustes/categorias/:id" do
      it "borra una categoría sin hijas ni movimientos" do
        delete category_path(transport)

        expect(response).to redirect_to(categories_path)
        expect(Category.exists?(transport.id)).to be(false)
      end

      it "no borra una categoría con hijas y ofrece archivarla" do
        create(:category, :child, household: household, parent: transport, name: "Gasolina")

        delete category_path(transport)

        expect(response).to redirect_to(edit_category_path(transport))
        expect(flash[:error]).to eq(I18n.t("categories.destroy.in_use"))
        expect(Category.exists?(transport.id)).to be(true)
      end
    end

    describe "aislamiento por hogar" do
      let!(:foreign) { create(:category, name: "Ajena") }

      it "devuelve 404 en todas las acciones sobre una categoría de otro hogar" do
        get edit_category_path(foreign)
        expect(response).to have_http_status(:not_found)

        patch category_path(foreign), params: { category: { name: "Mía" } }
        expect(response).to have_http_status(:not_found)

        delete category_path(foreign)
        expect(response).to have_http_status(:not_found)

        post category_archive_path(foreign)
        expect(response).to have_http_status(:not_found)

        delete category_archive_path(foreign)
        expect(response).to have_http_status(:not_found)

        patch category_position_path(foreign), params: { direction: "up" }
        expect(response).to have_http_status(:not_found)

        expect(foreign.reload).to have_attributes(name: "Ajena", archived_at: nil)
      end

      it "no deja colgar una hija de un padre de otro hogar" do
        post categories_path, params: valid_params.deep_merge(category: { parent_id: foreign.id })

        expect(response).to have_http_status(:unprocessable_content)
        expect(foreign.reload.children.count).to eq(0)
      end
    end
  end
end
