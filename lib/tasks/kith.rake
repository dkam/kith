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

  desc "List everyone and the rank they hold (kith:roles)"
  task roles: :environment do
    Member.includes(:actor).sort_by { |m| [ -m.rank, m.handle ] }.each do |member|
      puts format("%-10s %-10s %s", member.role, "@#{member.handle}", member.email_address)
    end
  end

  desc "Set a member's role (kith:role[email,moderator])"
  task :role, %i[ email_address role ] => :environment do |_task, args|
    usage = "Usage: rake kith:role[someone@example.com,#{Member.roles.keys.join("|")}]"

    email_address = args[:email_address].presence || abort(usage)
    role = args[:role].presence || abort(usage)

    abort "#{role.inspect} is not a role. #{usage}" unless Member.roles.key?(role)

    member = Member.find_by(email_address: email_address.strip.downcase) || abort("No member with that email address.")
    was = member.role

    # Deliberately not asked through Authority: there is no current member at a
    # console, and reading the server's console is already the highest
    # credential this instance has. Authority guards what members do to each
    # other through the app; this is the operator, underneath all of that.
    abort member.errors.full_messages.join("\n") unless member.update(role: role)

    puts "@#{member.handle} is #{member.role} (was #{was})"
  end

  desc "How Kith grows: the door, the cap, and everyone's allowance (kith:invites)"
  task invites: :environment do
    instance = Instance.current

    puts instance.accepting_members? ? "Open." : instance.closed_because
    puts "Members:   #{Member.count}#{" of #{instance.member_cap}" if instance.member_cap}"
    puts

    Member.includes(:actor).sort_by(&:handle).each do |member|
      puts format("  %-12s %d of %d left", "@#{member.handle}", member.invites_left, member.invite_allowance)
    end
  end

  desc "Open or close the door (kith:door[open] / kith:door[closed])"
  task :door, %i[ state ] => :environment do |_task, args|
    state = args[:state].presence || abort("Usage: rake kith:door[open|closed]")
    abort "Usage: rake kith:door[open|closed]" unless %w[ open closed ].include?(state)

    Instance.current.update!(invites_open: state == "open")

    puts state == "open" ? "Invites are open." : "Invites are closed. Outstanding ones stop working too."
  end

  desc "Cap how many members Kith will hold, or pass nothing to lift it (kith:member_cap[40])"
  task :member_cap, %i[ cap ] => :environment do |_task, args|
    instance = Instance.current

    abort instance.errors.full_messages.join("\n") unless instance.update(member_cap: args[:cap].presence&.to_i)

    if instance.member_cap
      puts "Capped at #{instance.member_cap}. #{Member.count} so far#{instance.full? ? " — full." : "."}"
    else
      puts "No cap."
    end
  end

  desc "Set how many people one member may bring in (kith:allowance[email,10])"
  task :allowance, %i[ email_address allowance ] => :environment do |_task, args|
    usage = "Usage: rake kith:allowance[someone@example.com,10]"

    email_address = args[:email_address].presence || abort(usage)
    allowance = args[:allowance].presence || abort(usage)

    member = Member.find_by(email_address: email_address.strip.downcase) || abort("No member with that email address.")
    abort member.errors.full_messages.join("\n") unless member.update(invite_allowance: allowance.to_i)

    puts "@#{member.handle}: #{member.invites_left} of #{member.invite_allowance} left"
  end
end
