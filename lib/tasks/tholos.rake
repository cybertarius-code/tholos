# frozen_string_literal: true

namespace :tholos do
  namespace :create_user do
    desc "Creates a new user with the given email and password. If the user already exists, it will not create a new one."
    task :with_email_and_password, [:email, :password] => :environment do |t, args|
      email = args[:email]
      password = args[:password]

      if email.nil? || password.nil?
        puts "Usage: rake tholos:create_user:with_email_and_password[email,password]"
        exit 1
      end

      user = User.find_by(email: email)

      if user
        puts "User with email #{email} already exists."
      else
        user = User.create_with_household!(email: email, password: password)
        if user.persisted?
          puts "User with email #{email} created successfully."
        else
          puts "Failed to create user: #{user.errors.full_messages.join(', ')}"
        end
      end
    end
  end
end
