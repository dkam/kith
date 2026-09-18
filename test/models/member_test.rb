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
end
