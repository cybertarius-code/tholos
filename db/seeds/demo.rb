# Seeds de demostración: usuario demo con su hogar.
# La contraseña es solo para local; nunca se versiona ni va a la bóveda.
# Se puede sobrescribir con THOLOS_DEMO_PASSWORD si hace falta.

demo_email = "demo@tholos.local"
demo_password = ENV.fetch("THOLOS_DEMO_PASSWORD", "tholos-demo-local")

# strict_loading está activo en development/test: precargar households.
user = User.includes(:households).find_by(email_address: demo_email)
household = user&.households&.first

if user.nil?
  User.create_with_household!(
    email: demo_email,
    password: demo_password,
    household_name: "Hogar Demo"
  )
  user = User.includes(:households).find_by!(email_address: demo_email)
  household = user.households.first
elsif household.nil?
  household = Household.create!(name: "Hogar Demo")
  Membership.create!(user: user, household: household, role: :owner)
end

puts "Seed demo: usuario #{user.email_address} (id #{user.id})"
puts "Seed demo: hogar #{household.name} (id #{household.id})"
