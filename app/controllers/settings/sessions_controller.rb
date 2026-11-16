module Settings
  class SessionsController < ApplicationController
    def index
      @sessions = Current.user.sessions.order(updated_at: :desc)
    end

    def destroy
      Current.user.sessions.where.not(id: Current.session.id).find(params[:id]).destroy
      redirect_to settings_sessions_path, success: t("settings.sessions.destroy.success"), status: :see_other
    end
  end
end
