module SetCurrentHousehold
  extend ActiveSupport::Concern

  included do
    before_action :set_current_household
  end

  private
    def set_current_household
      return unless Current.user

      # El household elegido solo vale si pertenece al usuario; si no, el primero
      Current.household =
        Current.user.households.find_by(id: session[:household_id]) ||
        Current.user.households.order(:id).first ||
        # Todo usuario nace con hogar (User.create_with_household!); sin él es un bug, no un caso de uso
        raise(ActiveRecord::RecordNotFound, "El usuario #{Current.user.id} no tiene hogar")
    end
end
