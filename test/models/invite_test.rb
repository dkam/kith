require "test_helper"

class InviteTest < ActiveSupport::TestCase
  test "a new invite gets a code and an expiry" do
    invite = members(:alice).issued_invites.create!

    assert_equal Invite::CODE_LENGTH, invite.code.length
    assert_in_delta Invite::LIFETIME.from_now, invite.expires_at, 5.seconds
    assert invite.open?
  end

  test "codes are unique" do
    invite = members(:alice).issued_invites.create!

    duplicate = members(:alice).issued_invites.build(code: invite.code)
    refute duplicate.valid?
  end

  test "status covers the three states" do
    assert_equal :open, invites(:open).status
    assert_equal :expired, invites(:expired).status
    assert_equal :claimed, invites(:claimed).status
  end

  test "an expired invite is not open even though it is unclaimed" do
    refute invites(:expired).open?
    refute invites(:expired).claimed?
    assert invites(:expired).expired?
  end

  test "the open scope excludes claimed and expired invites" do
    assert_equal [ invites(:open) ], Invite.open.to_a
  end

  test "claiming records who spent it" do
    invite = invites(:open)
    invite.claim!(members(:dave))

    assert_equal members(:dave), invite.claimed_by_member
    assert invite.claimed?
    refute invite.open?
  end

  test "an invite is single use" do
    error = assert_raises ActiveRecord::RecordInvalid do
      invites(:claimed).claim!(members(:dave))
    end

    assert_match "already been used", error.message
    assert_equal members(:bob), invites(:claimed).reload.claimed_by_member
  end

  test "an expired invite cannot be claimed" do
    assert_raises ActiveRecord::RecordInvalid do
      invites(:expired).claim!(members(:dave))
    end

    assert_nil invites(:expired).reload.claimed_by_member
  end

  test "two people racing for one invite: exactly one wins" do
    invite = invites(:open)
    other = Invite.find(invite.id)

    invite.claim!(members(:dave))

    assert_raises ActiveRecord::RecordInvalid do
      other.claim!(members(:carol))
    end

    assert_equal members(:dave), invite.reload.claimed_by_member
  end

  test "destroying a member destroys the invites they issued" do
    assert_difference -> { Invite.count }, -3 do
      members(:alice).destroy
    end
  end
end
