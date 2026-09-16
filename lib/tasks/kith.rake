namespace :kith do
  desc "Create the first member, who has no inviter (kith:first_member[email,handle,display_name])"
  task :first_member, %i[ email_address handle display_name ] => :environment do |_task, args|
    email_address = args[:email_address].presence || abort("Usage: rake kith:first_member[email,handle,\"Display Name\"]")
    handle = args[:handle].presence || abort("Usage: rake kith:first_member[email,handle,\"Display Name\"]")

    password = SecureRandom.alphanumeric(24)

    member = Member.create_first(
      email_address:, handle:, display_name: args[:display_name],
      password:, password_confirmation: password
    )

    abort member.errors.full_messages.join("\n") unless member.persisted?

    puts "Created @#{member.handle} <#{member.email_address}>"
    puts "Password: #{password}"
    puts "Sign in and change it."
  end

  desc "Print the setup code, if nobody has joined yet"
  task setup_code: :environment do
    abort "Kith already has a member; setup is closed." unless Setup.open?

    puts Setup.banner
  end
end
