class ApplicationMailer < ActionMailer::Base
  # Kith sends as itself. Not as a person, and not from example.com: a relay
  # checks the sending domain against the one it relays for, and whatever is
  # here is what the member's mail client puts at the top of the message.
  #
  # A proc rather than a string, because it is read when the mail is built
  # rather than when this class is loaded — which is what lets the address
  # follow KITH_HOST instead of being a second place to keep the hostname.
  default from: -> { ENV["KITH_MAIL_FROM"].presence || "kith@#{ENV["KITH_HOST"].presence || "localhost"}" }

  layout "mailer"
end
