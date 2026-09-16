require "test_helper"

class MemberClaimTest < ActiveSupport::TestCase
  test "claiming an invite creates a member, an actor, and spends the invite" do
    invite = invites(:open)

    member = nil
    assert_difference [ -> { Member.count }, -> { Actor.count } ], 1 do
      member = claim(invite)
    end

    assert member.persisted?
    assert_equal "zoe", member.handle
    assert_equal "Zoe Adeyemi", member.display_name
    assert_equal members(:alice), member.inviter_member
    assert_equal member, invite.reload.claimed_by_member
    assert_instance_of LocalActor, member.actor
  end

  test "the display name falls back to the handle" do
    member = claim(invites(:open), display_name: "")
    assert_equal "zoe", member.display_name
  end

  test "a failed registration leaves no member, no actor, and an unspent invite" do
    invite = invites(:open)

    assert_no_difference [ -> { Member.count }, -> { Actor.count } ] do
      member = claim(invite, handle: "alice")

      refute member.persisted?
      assert_includes member.errors.full_messages.join(" "), "Handle has already been taken"
    end

    assert invite.reload.open?
  end

  test "a bad email leaves nothing behind either" do
    assert_no_difference [ -> { Member.count }, -> { Actor.count } ] do
      member = claim(invites(:open), email_address: "nope")
      refute member.persisted?
    end
  end

  test "losing the race for an invite reports it and creates nothing" do
    invite = invites(:open)
    Invite.find(invite.id).claim!(members(:dave))

    assert_no_difference [ -> { Member.count }, -> { Actor.count } ] do
      member = claim(invite)

      refute member.persisted?
      assert_includes member.errors[:base], "That invite has been used already, or has expired."
    end
  end

  private
    def claim(invite, handle: "zoe", display_name: "Zoe Adeyemi", email_address: "zoe@example.com", password: "password123")
      Member.claim(invite, handle:, display_name:, email_address:, password:, password_confirmation: password)
    end
end
