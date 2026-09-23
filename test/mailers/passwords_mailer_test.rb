# frozen_string_literal: true

require "test_helper"

# The one email Kith sends. Two things about it are configuration rather than
# code, and both fail silently: where the link points, and who it comes from.
# ProductionTest covers the link; this covers the sender, which a relay checks
# against the domain it is relaying for and a mail client puts in front of the
# member.
class PasswordsMailerTest < ActionMailer::TestCase
  test "the reset comes from this Kith, not from a person and not from example.com" do
    with_env("KITH_HOST" => "kith.example.org") do
      assert_equal [ "kith@kith.example.org" ], PasswordsMailer.reset(members(:alice)).from
    end
  end

  test "a relay that insists on one particular sender can be given one" do
    with_env("KITH_HOST" => "kith.example.org", "KITH_MAIL_FROM" => "no-reply@example.org") do
      assert_equal [ "no-reply@example.org" ], PasswordsMailer.reset(members(:alice)).from
    end
  end

  test "the link carries the token that opens the member's reset page" do
    mail = PasswordsMailer.reset(members(:alice))

    assert_equal [ members(:alice).email_address ], mail.to
    assert_match %r{/passwords/[^/]+/edit}, mail.text_part.body.to_s
  end

  private
    def with_env(values)
      held = ENV.slice(*values.keys)
      ENV.update(values)
      yield
    ensure
      values.each_key { |name| ENV.delete(name) }
      ENV.update(held)
    end
end
