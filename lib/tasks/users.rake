# frozen_string_literal: true

namespace :users do
  desc 'Crea un usuario con su hogar y membresía owner: bin/rails "users:create[email,password,nombre_hogar]"'
  task :create, [ :email, :password, :household_name ] => :environment do |_task, args|
    email = args[:email]
    password = args[:password]

    abort 'Uso: bin/rails "users:create[email,password,nombre_hogar]" (nombre_hogar es opcional)' if email.blank? || password.blank?
    abort "Ya existe un usuario con el email #{email}" if User.exists?(email_address: email)

    # Sin rescue: un fallo de validación o de BD aborta la tarea con su error y la transacción deja la BD intacta
    user = User.create_with_household!(email: email, password: password, household_name: args[:household_name])
    membership = Membership.includes(:household).find_by!(user: user)

    puts "Usuario #{user.email_address} creado: hogar \"#{membership.household.name}\", rol #{membership.role}"
  end
end
