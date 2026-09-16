require "test_helper"

# What a member may *do*. The companion test to VisibilityTest, which covers
# what a member may *see* — and the pair are kept apart on purpose, because
# the one thing a role must never do is show somebody something.
#
# The role fixtures:
#
#   alice   owner       (claimed the instance; connected to bob, follows carol)
#   bob     member
#   carol   member      (invisible)
#   dave    member
#   mo      moderator   (follows nobody, nobody follows them)
#   ada     admin       (follows nobody, nobody follows them)
class AuthorityTest < ActiveSupport::TestCase
  # --- Ranks ----------------------------------------------------------------

  test "a new member is ordinary" do
    assert_equal "member", Member.new.role
  end

  test "moderating is the floor for admins and the owner too" do
    refute as(:bob).moderates?
    assert as(:mo).moderates?
    assert as(:ada).moderates?
    assert as(:alice).moderates?
  end

  test "administering starts at admin" do
    refute as(:mo).administers?
    assert as(:ada).administers?
    assert as(:alice).administers?
  end

  test "only the owner owns" do
    refute as(:ada).owns?
    assert as(:alice).owns?
  end

  test "a signed-out visitor holds no rank at all" do
    refute signed_out.moderates?
    refute signed_out.administers?
    refute signed_out.owns?
  end

  # --- Posts ----------------------------------------------------------------

  test "an author edits and deletes their own post" do
    assert as(:alice).edit_post?(posts(:alice_followers))
    assert as(:alice).delete_post?(posts(:alice_followers))
  end

  test "an ordinary member touches nobody else's post" do
    refute as(:bob).edit_post?(posts(:alice_followers))
    refute as(:bob).delete_post?(posts(:alice_followers))
  end

  test "a moderator deletes a post they can see" do
    assert as(:mo).delete_post?(posts(:alice_public))
  end

  test "a moderator does not rewrite what someone else wrote" do
    refute as(:mo).edit_post?(posts(:alice_public))
    refute as(:ada).edit_post?(posts(:alice_public))
    refute as(:alice).edit_post?(posts(:bob_followers))
  end

  test "a moderator cannot delete a post they cannot see" do
    refute as(:mo).delete_post?(posts(:alice_followers)),
      "moderation acts on what is already in front of you; it is not a way in"
  end

  test "a moderator who is an accepted follower can delete what they can now see" do
    Follow.create!(follower_actor: actors(:mo), followed_actor: actors(:alice)).accept!

    assert Authority.new(members(:mo).reload).delete_post?(posts(:alice_followers))
  end

  test "admins and the owner moderate as well" do
    assert as(:ada).delete_post?(posts(:alice_public))
    assert as(:alice).delete_post?(posts(:bob_followers))
  end

  test "a signed-out visitor deletes nothing, not even a public post" do
    refute signed_out.delete_post?(posts(:alice_public))
    refute signed_out.edit_post?(posts(:alice_public))
  end

  test "a nil post is never actionable" do
    refute as(:alice).delete_post?(nil)
    refute as(:alice).edit_post?(nil)
  end

  # --- Comments -------------------------------------------------------------

  test "you delete your own reply" do
    assert as(:bob).delete_comment?(comments(:bob_on_alice_followers))
  end

  test "the post's author deletes replies on their post" do
    assert as(:alice).delete_comment?(comments(:bob_on_alice_followers))
  end

  test "an ordinary member deletes nobody else's reply" do
    refute as(:bob).delete_comment?(comments(:alice_on_alice_followers))
  end

  test "a moderator deletes a reply they can see" do
    assert as(:mo).delete_comment?(comments(:bob_on_alice_public))
  end

  test "a moderator cannot delete a reply on a post they cannot see" do
    refute as(:mo).delete_comment?(comments(:bob_on_alice_followers))
  end

  test "an invisible member's reply is not moderatable by someone it is hidden from" do
    refute as(:mo).delete_comment?(comments(:carol_on_alice_public)),
      "carol is invisible and mo is not connected to her: the reply is not there to be deleted"
    refute as(:ada).delete_comment?(comments(:carol_on_alice_public))
  end

  test "a nil comment is never actionable" do
    refute as(:alice).delete_comment?(nil)
  end

  # --- Invites --------------------------------------------------------------

  test "a member with allowance left may invite" do
    assert as(:bob).issue_invite?
  end

  test "a member who has spent their allowance may not" do
    members(:bob).update!(invite_allowance: members(:bob).invites_spent)

    refute Authority.new(members(:bob).reload).issue_invite?
  end

  test "an allowance of zero is a member who may not invite at all" do
    members(:bob).update!(invite_allowance: 0)

    refute Authority.new(members(:bob).reload).issue_invite?
  end

  test "a closed instance overrides every allowance, the owner's included" do
    Instance.current.update!(invites_open: false)

    refute as(:bob).issue_invite?
    refute as(:ada).issue_invite?, "an admin does not get to walk through a closed door"
    refute as(:alice).issue_invite?, "nor does the owner"
  end

  test "a full instance overrides every allowance too" do
    Instance.current.update!(member_cap: Member.count)

    refute as(:alice).issue_invite?
  end

  test "a signed-out visitor invites nobody" do
    refute signed_out.issue_invite?
  end

  test "only an admin changes how Kith grows" do
    refute as(:bob).manage_invites?
    refute as(:mo).manage_invites?
    assert as(:ada).manage_invites?
    assert as(:alice).manage_invites?
    refute signed_out.manage_invites?
  end

  # --- Handing out roles ----------------------------------------------------

  test "the owner promotes a member to admin" do
    assert as(:alice).assign_role?(members(:bob), to: :admin)
  end

  test "an admin promotes a member to moderator" do
    assert as(:ada).assign_role?(members(:bob), to: :moderator)
  end

  test "an admin cannot make another admin" do
    refute as(:ada).assign_role?(members(:bob), to: :admin),
      "you cannot hand out a rank you do not outrank"
  end

  test "nobody hands out ownership: it is transferred deliberately, not assigned" do
    refute as(:alice).assign_role?(members(:bob), to: :owner)
  end

  test "an admin cannot demote another admin, or the owner" do
    refute as(:ada).assign_role?(members(:alice), to: :member)
    other_admin = members(:dave).tap { |m| m.update!(role: :admin) }
    refute as(:ada).assign_role?(other_admin, to: :member)
  end

  test "the owner demotes an admin" do
    assert as(:alice).assign_role?(members(:ada), to: :member)
  end

  test "nobody changes their own role" do
    refute as(:alice).assign_role?(members(:alice), to: :member)
    refute as(:ada).assign_role?(members(:ada), to: :owner)
  end

  test "a moderator hands out nothing" do
    refute as(:mo).assign_role?(members(:bob), to: :moderator)
  end

  test "an ordinary member hands out nothing" do
    refute as(:bob).assign_role?(members(:dave), to: :moderator)
  end

  test "a signed-out visitor hands out nothing" do
    refute signed_out.assign_role?(members(:bob), to: :moderator)
  end

  test "an unknown role is never assignable" do
    refute as(:alice).assign_role?(members(:bob), to: :sysop)
  end

  private
    def as(name) = Authority.new(members(name))
    def signed_out = Authority.new(nil)
end
