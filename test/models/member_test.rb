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

  test "create_first makes an inviterless member, discoverable by everyone" do
    Member.destroy_all

    member = Member.create_first(handle: "zoe", display_name: nil, email_address: "zoe@example.com",
      password: "password123", password_confirmation: "password123")

    assert member.persisted?
    assert_nil member.inviter_member
    assert_equal "zoe", member.display_name, "a blank name falls back to the handle"
    assert member.actor.everyone?
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
