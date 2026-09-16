namespace :kith do
  desc "Create the first member, who has no inviter (kith:first_member[email,handle,display_name])"
  task :first_member, %i[ email_address handle display_name ] => :environment do |_task, args|
    abort "A member already exists; invite them instead." if Member.exists?

    email_address = args[:email_address].presence || abort("Usage: rake kith:first_member[email,handle,\"Display Name\"]")
    handle = args[:handle].presence || abort("Usage: rake kith:first_member[email,handle,\"Display Name\"]")

    password = SecureRandom.alphanumeric(24)

    member = Member.new(email_address:, password:, password_confirmation: password)
    member.build_actor(type: "LocalActor", handle:, display_name: args[:display_name].presence || handle, discoverable: :everyone)

    if member.save
      puts "Created @#{member.handle} <#{member.email_address}>"
      puts "Password: #{password}"
      puts "Sign in and change it."
    else
      abort member.errors.full_messages.join("\n")
    end
  end
end
