class ApplicationController < ActionController::Base
  include Authentication
  include SetCurrentHousehold
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  add_flash_types :success, :error, :warning, :info
  helper_method :modal_request?

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  # Use in turbo_stream responses, where the layout is not rendered
  def flash_stream
    turbo_stream.update("flash", partial: "shared/flash_messages")
  end

  # Formularios abiertos en el modal "+ Movimiento" (US-0109): Turbo Frame "modal" del layout
  def modal_request?
    turbo_frame_request_id == "modal"
  end

  def modal_layout
    modal_request? ? "modal" : "application"
  end

  # Cuenta que "+ Movimiento" preselecciona la próxima vez (gastos, ingresos y transferencias)
  def remember_last_account(account_id)
    cookies.signed.permanent[:last_account_id] = { value: account_id, httponly: true, same_site: :lax }
  end

  # Cierra el modal, muestra el aviso y refresca la página de debajo (morphing).
  # El aviso va en esta respuesta y es permanente para que el morph no lo quite.
  # Sin request_id: Turbo ignora los refresh que llevan el id de una petición suya reciente.
  def close_modal_and_refresh(message)
    render turbo_stream: [
      turbo_stream.update("modal"),
      turbo_stream.append("flash", partial: "shared/flash_message", locals: { variant: :success, message: message, permanent: true }),
      turbo_stream.refresh(request_id: nil)
    ]
  end
end
