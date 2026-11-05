RSpec.shared_context "authentication helpers" do
  # Simula el login inyectando la cookie firmada directamente
  def sign_in_as(user)
    # Crea una sesión real en la base de datos asociada al usuario
    session = user.sessions.create!

    # Inyecta el ID de la sesión en el jar de cookies de la prueba
    # Usamos ActionDispatch::TestRequest para firmar correctamente la cookie como lo hace Rails
    ActionDispatch::TestRequest.create.cookie_jar.tap do |cookie_jar|
      cookie_jar.signed[:session_id] = session.id
      cookies[:session_id] = cookie_jar[:session_id]
    end

    # Adicionalmente, exponemos la sesión actual en el objeto Current de Rails 8
    Current.session = session
  end

  # Simula el logout eliminando la sesión y la cookie
  def sign_out
    Current.session&.destroy!
    cookies.delete(:session_id)
  end
end
