class PasswordsMailer < ApplicationMailer
  def reset(member)
    @member = member
    mail subject: "Reset your Kith password", to: member.email_address
  end
end
