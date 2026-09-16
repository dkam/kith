require "test_helper"

class InvitesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as members(:alice) }

  test "listing shows only your own invites" do
    other = members(:bob).issued_invites.create!

    get invites_url
    assert_response :success
    assert_select "##{dom_id(invites(:open))}"
    assert_select "##{dom_id(other)}", false
  end

  test "creating an invite" do
    assert_difference -> { members(:alice).issued_invites.count }, 1 do
      post invites_url
    end

    assert_redirected_to invites_url
  end

  test "revoking an unclaimed invite" do
    assert_difference -> { Invite.count }, -1 do
      delete invite_url(invites(:open))
    end
  end

  test "a claimed invite cannot be revoked" do
    assert_no_difference -> { Invite.count } do
      delete invite_url(invites(:claimed))
    end

    assert_response :not_found
  end

  test "you cannot revoke someone else's invite" do
    other = members(:bob).issued_invites.create!

    assert_no_difference -> { Invite.count } do
      delete invite_url(other)
    end

    assert_response :not_found
  end

  test "a member at their allowance is refused a new invite" do
    members(:alice).update!(invite_allowance: members(:alice).invites_spent)

    assert_no_difference -> { Invite.count } do
      post invites_url
    end

    assert_redirected_to invites_url
  end

  test "no invite button once the allowance is spent" do
    members(:alice).update!(invite_allowance: members(:alice).invites_spent)

    get invites_url
    assert_select "form[action=?]", invites_path, false
  end

  test "a closed instance refuses invites from the owner" do
    Instance.current.update!(invites_open: false)

    assert_no_difference -> { Invite.count } do
      post invites_url
    end

    get invites_url
    assert_select "form[action=?]", invites_path, false
    assert_match "Invites are closed", response.body
  end

  test "a full instance says so" do
    Instance.current.update!(member_cap: Member.count)

    get invites_url
    assert_match "Kith is full", response.body
  end

  test "invites require signing in" do
    sign_out
    get invites_url
    assert_redirected_to new_session_url
  end
end
