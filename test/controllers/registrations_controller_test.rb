require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "opening a valid invite" do
    get join_url(invites(:open).code)

    assert_response :success
    assert_select "h1", "Join Kith"
  end

  test "an expired invite is turned away" do
    get join_url(invites(:expired).code)

    assert_redirected_to new_session_url
    assert_match "used already, or has expired", flash[:alert]
  end

  test "a claimed invite is turned away" do
    get join_url(invites(:claimed).code)
    assert_redirected_to new_session_url
  end

  test "an invented code is turned away" do
    get join_url("notarealcode1234")
    assert_redirected_to new_session_url
  end

  test "joining creates the member and signs them in" do
    assert_difference -> { Member.count }, 1 do
      post join_url(invites(:open).code), params: registration_params
    end

    # A new member lands on their settings, not an empty feed: the first thing
    # to do here is say who you are.
    assert_redirected_to settings_url

    member = Member.find_by(email_address: "zoe@example.com")
    assert_equal members(:alice), member.inviter_member
    assert_equal invites(:open), member.claimed_invite

    get root_url
    assert_response :success
  end

  test "a taken handle re-renders the form and spends nothing" do
    assert_no_difference -> { Member.count } do
      post join_url(invites(:open).code), params: registration_params(handle: "alice")
    end

    assert_response :unprocessable_content
    assert_select "li", /Handle has already been taken/
    assert invites(:open).reload.open?
  end

  test "an already signed-in member is sent home" do
    sign_in_as members(:alice)

    get join_url(invites(:open).code)
    assert_redirected_to root_url
  end

  private
    def registration_params(handle: "zoe")
      {
        member: {
          email_address: "zoe@example.com",
          password: "password123",
          password_confirmation: "password123",
          actor_attributes: { handle: handle, display_name: "Zoe Adeyemi" }
        }
      }
    end
end
