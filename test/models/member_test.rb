require "test_helper"

class MemberTest < ActiveSupport::TestCase
  test "email addresses are normalised and unique" do
    member = build_member(email_address: "  ZOE@Example.COM ")
    assert member.valid?
    assert_equal "zoe@example.com", member.email_address

    duplicate = build_member(email_address: "ALICE@example.com", handle: "zoe2")
    refute duplicate.valid?
    assert_includes duplicate.errors[:email_address], "has already been taken"
  end

  test "email addresses must look like email addresses" do
    refute build_member(email_address: "not-an-email").valid?
  end

  test "passwords must be at least eight characters" do
    refute build_member(password: "short").valid?
  end

  test "a member delegates its public identity to its actor" do
    assert_equal "alice", members(:alice).handle
    assert_equal "Alice Brennan", members(:alice).display_name
  end

  test "only the first member may have no inviter" do
    assert_nil members(:alice).inviter_member
    assert_equal members(:alice), members(:bob).inviter_member
  end

  test "create_first refuses to run twice" do
    member = Member.create_first(handle: "zoe", display_name: "Zoe", email_address: "zoe@example.com",
      password: "password123", password_confirmation: "password123")

    assert_not member.persisted?
    assert_match "already has a member", member.errors.full_messages.to_sentence
  end

  test "create_first makes an inviterless member, discoverable by every member" do
    Member.destroy_all

    member = Member.create_first(handle: "zoe", display_name: nil, email_address: "zoe@example.com",
      password: "password123", password_confirmation: "password123")

    assert member.persisted?
    assert_nil member.inviter_member
    assert_equal "zoe", member.display_name, "a blank name falls back to the handle"
    assert member.actor.members?
  end

  test "reset_password! sets a random password and returns it" do
    alice = members(:alice)

    password = Member.reset_password!("alice@example.com")

    assert_equal 24, password.length
    assert_equal alice, Member.authenticate_by(email_address: "alice@example.com", password: password)
    assert_nil Member.authenticate_by(email_address: "alice@example.com", password: "password123")
  end

  test "reset_password! takes a password of your own" do
    Member.reset_password!("alice@example.com", "a better password")

    assert_equal members(:alice), Member.authenticate_by(email_address: "alice@example.com", password: "a better password")
  end

  test "reset_password! refuses a password the model would refuse" do
    assert_raises ActiveRecord::RecordInvalid do
      Member.reset_password!("alice@example.com", "short")
    end

    assert_equal members(:alice), Member.authenticate_by(email_address: "alice@example.com", password: "password123")
  end

  test "reset_password! signs the member out everywhere" do
    alice = members(:alice)
    alice.sessions.create!
    bob_session = members(:bob).sessions.create!

    alice.reset_password!

    assert_empty alice.sessions.reload
    assert Session.exists?(bob_session.id), "someone else's sessions are left alone"
  end

  test "reset_password! finds a member by handle, with or without the @" do
    assert_equal members(:alice), Member.find_by_identifier!("@Alice")
    assert_equal members(:alice), Member.find_by_identifier!(" alice ")
    assert_equal members(:alice), Member.find_by_identifier!("ALICE@example.com")

    assert_raises ActiveRecord::RecordNotFound do
      Member.reset_password!("nobody@example.com")
    end
  end

  # --- Roles ----------------------------------------------------------------

  test "a member is ordinary unless someone says otherwise" do
    assert build_member.member?
    assert members(:bob).member?
  end

  test "whoever claimed the instance owns it" do
    assert members(:alice).owner?
  end

  test "create_first makes the owner" do
    Member.destroy_all

    member = Member.create_first(handle: "zoe", display_name: "Zoe", email_address: "zoe@example.com",
      password: "password123", password_confirmation: "password123")

    assert member.owner?
  end

  test "a member claiming an invite is ordinary, whoever invited them" do
    member = Member.claim(invites(:open), handle: "zoe", display_name: "Zoe",
      email_address: "zoe@example.com", password: "password123", password_confirmation: "password123")

    assert member.persisted?
    assert member.member?, "an owner's invitee does not inherit the owner's rank"
  end

  test "roles rank, so a higher role carries the powers of a lower one" do
    assert members(:alice).moderates?
    assert members(:alice).administers?
    assert members(:ada).moderates?
    refute members(:mo).administers?
    refute members(:bob).moderates?
  end

  test "an unknown role is refused rather than raised" do
    member = members(:bob)
    member.role = "sysop"

    refute member.valid?
    assert_includes member.errors[:role], "is not a valid role"
  end

  test "the last owner cannot step down" do
    owner = members(:alice)
    owner.role = :admin

    refute owner.valid?
    assert_match "would leave Kith with no owner", owner.errors.full_messages.to_sentence
  end

  test "an owner can step down once somebody else owns the place" do
    members(:ada).update!(role: :owner)

    assert members(:alice).update(role: :admin)
  end

  test "promoting somebody to owner is not blocked by the owner who is already there" do
    assert members(:ada).update(role: :owner)
    assert members(:alice).reload.owner?, "Kith can hold two owners; it just cannot hold none"
  end

  # --- Invite allowance -------------------------------------------------------

  test "an open invite and a claimed one both count against the allowance" do
    # alice's fixtures: one open, one claimed, one expired-and-unclaimed.
    assert_equal 2, members(:alice).invites_spent
  end

  test "an expired unclaimed invite costs nothing: it brought nobody in" do
    before = members(:alice).invites_spent
    members(:alice).issued_invites.create!(expires_at: 1.day.ago)

    assert_equal before, members(:alice).reload.invites_spent
  end

  test "invites left is the allowance less what has been spent" do
    members(:alice).update!(invite_allowance: 5)

    assert_equal 3, members(:alice).invites_left
  end

  test "invites left never goes negative, however the allowance was lowered" do
    members(:alice).update!(invite_allowance: 1)

    assert_equal 0, members(:alice).invites_left
  end

  test "authenticate_by verifies the password" do
    assert_equal members(:alice), Member.authenticate_by(email_address: "alice@example.com", password: "password123")
    assert_nil Member.authenticate_by(email_address: "alice@example.com", password: "wrong")
  end

  private
    def build_member(handle: "zoe", email_address: "zoe@example.com", password: "password123")
      member = Member.new(email_address:, password:, password_confirmation: password)
      member.build_actor(type: "LocalActor", handle:, display_name: "Zoe")
      member
    end

  test "a time zone is optional, and has to be one that exists" do
    member = members(:alice)

    assert member.update(time_zone: "Melbourne")
    assert member.update(time_zone: nil), "nobody has to tell Kith where they are"
    refute member.update(time_zone: "Middle Earth")
  end

  test "a member with no time zone falls back to the instance's" do
    assert_equal Time.zone, members(:alice).zone
    assert_equal ActiveSupport::TimeZone["Melbourne"], members(:alice).tap { |m| m.time_zone = "Melbourne" }.zone
  end
end
