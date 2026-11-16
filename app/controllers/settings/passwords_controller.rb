module Settings
  class PasswordsController < ApplicationController
    def edit
      redirect_to settings_sessions_path
    end

    def update
      if Current.user.update(user_params)
        Current.user.sessions.where.not(id: Current.session.id).destroy_all
        redirect_to settings_sessions_path, success: t("settings.passwords.update.success")
      elsif Current.user.errors.of_kind?(:password_challenge, :invalid)
        redirect_to settings_sessions_path, error: t("settings.passwords.update.wrong_current")
      else
        redirect_to settings_sessions_path, error: t("settings.passwords.update.failure")
      end
    end

    private
      def user_params
        params.require(:user).permit(:password, :password_confirmation, :password_challenge).with_defaults(password_challenge: "")
      end
  end
end
