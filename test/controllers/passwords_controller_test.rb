require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  test "requesting a reset emails the member" do
    assert_enqueued_emails 1 do
      post passwords_url, params: { email_address: "alice@example.com" }
    end

    assert_redirected_to new_session_url
  end

  test "requesting a reset for an unknown address says the same thing and sends nothing" do
    assert_no_enqueued_emails do
      post passwords_url, params: { email_address: "nobody@example.com" }
    end

    assert_redirected_to new_session_url
    assert_match "if a member with that email address exists", flash[:notice]
  end

  test "resetting a password signs out every session" do
    member = members(:alice)
    member.sessions.create!

    put password_url(member.password_reset_token), params: { password: "newpassword", password_confirmation: "newpassword" }

    assert_redirected_to new_session_url
    assert_empty member.sessions.reload
    assert member.reload.authenticate("newpassword")
  end

  test "an invalid token is rejected" do
    put password_url("nonsense"), params: { password: "newpassword", password_confirmation: "newpassword" }
    assert_redirected_to new_password_url
  end
end
