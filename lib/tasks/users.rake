namespace :users do
  desc "Create a user. Usage: bin/rails users:create EMAIL=foo@bar.com PASSWORD=secret"
  task create: :environment do
    email = ENV["EMAIL"] or abort "EMAIL required"
    password = ENV["PASSWORD"] or abort "PASSWORD required"

    user = User.create!(email: email, password: password, password_confirmation: password)
    puts "Created user ##{user.id} (#{user.email})"
  end
end
